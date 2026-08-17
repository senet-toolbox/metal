const std = @import("std");
const posix = std.posix;
const system = posix.system;
const windows = posix.windows;
const native_os = builtin.os.tag;
const socket_t = posix.socket_t;
const sockaddr = posix.sockaddr;
const socklen_t = posix.socklen_t;
const errno = posix.errno;
const SOCK = posix.SOCK;
const builtin = @import("builtin");
const fd_t = posix.fd_t;
const F = posix.F;
const O = posix.O;
const FD_CLOEXEC = posix.FD_CLOEXEC;

pub const SocketError = error{
    /// Permission to create a socket of the specified type and/or
    /// pro‐tocol is denied.
    PermissionDenied,

    /// The implementation does not support the specified address family.
    AddressFamilyNotSupported,

    /// Unknown protocol, or protocol family not available.
    ProtocolFamilyNotAvailable,

    /// The per-process limit on the number of open file descriptors has been reached.
    ProcessFdQuotaExceeded,

    /// The system-wide limit on the total number of open files has been reached.
    SystemFdQuotaExceeded,

    /// Insufficient memory is available. The socket cannot be created until sufficient
    /// resources are freed.
    SystemResources,

    /// The protocol type or the specified protocol is not supported within this domain.
    ProtocolNotSupported,

    /// The socket type is not supported by the protocol.
    SocketTypeNotSupported,
} || UnexpectedError;

pub const UnexpectedError = error{
    /// The Operating System returned an undocumented error code.
    ///
    /// This error is in theory not possible, but it would be better
    /// to handle this error than to invoke undefined behavior.
    ///
    /// When this error code is observed, it usually means the Zig Standard
    /// Library needs a small patch to add the error code to the error set for
    /// the respective function.
    Unexpected,
};

pub const unexpected_error_tracing = builtin.zig_backend == .stage2_llvm and builtin.mode == .Debug;

/// Call this when you made a syscall or something that sets errno
/// and you get an unexpected error.
pub fn unexpectedErrno(err: posix.system.E) UnexpectedError {
    if (unexpected_error_tracing) {
        std.debug.print("unexpected errno: {d}\n", .{@intFromEnum(err)});
        std.debug.dumpCurrentStackTrace(.{});
    }
    return error.Unexpected;
}

pub fn close(fd: fd_t) void {
    switch (errno(system.close(fd))) {
        .BADF => unreachable, // Always a race condition.
        .INTR => return, // This is still a success. See https://github.com/ziglang/zig/issues/2425
        else => return,
    }
}

pub fn socket(domain: u32, socket_type: u32, protocol: u32) anyerror!posix.socket_t {
    if (native_os == .windows) {
        // These flags are not actually part of the Windows API, instead they are converted here for compatibility
        const filtered_sock_type = socket_type & ~@as(u32, SOCK.NONBLOCK | SOCK.CLOEXEC);
        var flags: u32 = windows.ws2_32.WSA_FLAG_OVERLAPPED;
        if ((socket_type & SOCK.CLOEXEC) != 0) flags |= windows.ws2_32.WSA_FLAG_NO_HANDLE_INHERIT;

        const rc = try windows.WSASocketW(
            @bitCast(domain),
            @bitCast(filtered_sock_type),
            @bitCast(protocol),
            null,
            0,
            flags,
        );
        errdefer windows.closesocket(rc) catch unreachable;
        if ((socket_type & SOCK.NONBLOCK) != 0) {
            var mode: c_ulong = 1; // nonblocking
            if (windows.ws2_32.SOCKET_ERROR == windows.ws2_32.ioctlsocket(rc, windows.ws2_32.FIONBIO, &mode)) {
                switch (windows.ws2_32.WSAGetLastError()) {
                    // have not identified any error codes that should be handled yet
                    else => unreachable,
                }
            }
        }
        return rc;
    }

    const have_sock_flags = !builtin.target.os.tag.isDarwin() and native_os != .haiku;
    const filtered_sock_type = if (!have_sock_flags)
        socket_type & ~@as(u32, SOCK.NONBLOCK | SOCK.CLOEXEC)
    else
        socket_type;
    const rc = system.socket(domain, filtered_sock_type, protocol);
    switch (errno(rc)) {
        .SUCCESS => {
            const fd: fd_t = @intCast(rc);
            errdefer close(fd);
            if (!have_sock_flags) {
                try setSockFlags(fd, socket_type);
            }
            return fd;
        },
        .ACCES => return error.AccessDenied,
        .AFNOSUPPORT => return error.AddressFamilyNotSupported,
        .INVAL => return error.ProtocolFamilyNotAvailable,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOBUFS => return error.SystemResources,
        .NOMEM => return error.SystemResources,
        .PROTONOSUPPORT => return error.ProtocolNotSupported,
        .PROTOTYPE => return error.SocketTypeNotSupported,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn listen(sock: posix.socket_t, backlog: u31) anyerror!void {
    const rc = system.listen(sock, backlog);
    switch (errno(rc)) {
        .SUCCESS => return,
        .ADDRINUSE => return error.AddressInUse,
        .BADF => unreachable,
        .NOTSOCK => return error.FileDescriptorNotASocket,
        .OPNOTSUPP => return error.OperationNotSupported,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn bind(sock: socket_t, addr: *const sockaddr, len: socklen_t) anyerror!void {
    if (native_os == .windows) {
        const rc = windows.bind(sock, addr, len);
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable, // not initialized WSA
                .WSAEACCES => return error.AccessDenied,
                .WSAEADDRINUSE => return error.AddressInUse,
                .WSAEADDRNOTAVAIL => return error.AddressNotAvailable,
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEFAULT => unreachable, // invalid pointers
                .WSAEINVAL => return error.AlreadyBound,
                .WSAENOBUFS => return error.SystemResources,
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                else => |err| return windows.unexpectedWSAError(err),
            }
            unreachable;
        }
        return;
    } else {
        const rc = system.bind(sock, addr, len);
        switch (errno(rc)) {
            .SUCCESS => return,
            .ACCES, .PERM => return error.AccessDenied,
            .ADDRINUSE => return error.AddressInUse,
            .BADF => unreachable, // always a race condition if this error is returned
            .INVAL => unreachable, // invalid parameters
            .NOTSOCK => unreachable, // invalid `sockfd`
            .AFNOSUPPORT => return error.AddressFamilyNotSupported,
            .ADDRNOTAVAIL => return error.AddressNotAvailable,
            .FAULT => unreachable, // invalid `addr` pointer
            .LOOP => return error.SymLinkLoop,
            .NAMETOOLONG => return error.NameTooLong,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOTDIR => return error.NotDir,
            .ROFS => return error.ReadOnlyFileSystem,
            else => |err| return unexpectedErrno(err),
        }
    }
    unreachable;
}

pub fn accept(
    /// This argument is a socket that has been created with `socket`, bound to a local address
    /// with `bind`, and is listening for connections after a `listen`.
    sock: posix.socket_t,
    /// This argument is a pointer to a sockaddr structure.  This structure is filled in with  the
    /// address  of  the  peer  socket, as known to the communications layer.  The exact format of the
    /// address returned addr is determined by the socket's address  family  (see  `socket`  and  the
    /// respective  protocol  man  pages).
    addr: ?*posix.sockaddr,
    /// This argument is a value-result argument: the caller must initialize it to contain  the
    /// size (in bytes) of the structure pointed to by addr; on return it will contain the actual size
    /// of the peer address.
    ///
    /// The returned address is truncated if the buffer provided is too small; in this  case,  `addr_size`
    /// will return a value greater than was supplied to the call.
    addr_size: ?*posix.socklen_t,
    /// The following values can be bitwise ORed in flags to obtain different behavior:
    /// * `SOCK.NONBLOCK` - Set the `NONBLOCK` file status flag on the open file description (see `open`)
    ///   referred  to by the new file descriptor.  Using this flag saves extra calls to `fcntl` to achieve
    ///   the same result.
    /// * `SOCK.CLOEXEC`  - Set the close-on-exec (`FD_CLOEXEC`) flag on the new file descriptor.   See  the
    ///   description  of the `CLOEXEC` flag in `open` for reasons why this may be useful.
    flags: u32,
) anyerror!posix.socket_t {
    const have_accept4 = !(builtin.target.isDarwinLibC() or builtin.os.tag == .windows or builtin.os.tag == .linux);
    std.debug.assert(0 == (flags & ~@as(u32, posix.SOCK.NONBLOCK | posix.SOCK.CLOEXEC))); // Unsupported flag(s)

    const accepted_sock: posix.socket_t = while (true) {
        const rc = if (have_accept4)
            system.accept4(sock, addr, addr_size, flags)
        else
            system.accept(sock, addr, addr_size);

        switch (errno(rc)) {
            .SUCCESS => break @intCast(rc),
            .INTR => continue,
            .AGAIN => return error.WouldBlock,
            .BADF => unreachable, // always a race condition
            .CONNABORTED => return error.ConnectionAborted,
            .FAULT => unreachable,
            .INVAL => return error.SocketNotListening,
            .NOTSOCK => unreachable,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .OPNOTSUPP => unreachable,
            .PROTO => return error.ProtocolFailure,
            .PERM => return error.BlockedByFirewall,
            else => |err| return unexpectedErrno(err),
        }
    };

    errdefer close(accepted_sock);
    if (!have_accept4) {
        try setSockFlags(accepted_sock, flags);
    }
    return accepted_sock;
}

pub fn fcntl(fd: fd_t, cmd: i32, arg: usize) anyerror!usize {
    while (true) {
        const rc = system.fcntl(fd, cmd, arg);
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .AGAIN, .ACCES => return error.Locked,
            .BADF => unreachable,
            .BUSY => return error.FileBusy,
            .INVAL => unreachable, // invalid parameters
            .PERM => return error.PermissionDenied,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NOTDIR => unreachable, // invalid parameter
            .DEADLK => return error.DeadLock,
            .NOLCK => return error.LockedRegionLimitExceeded,
            else => |err| return unexpectedErrno(err),
        }
    }
}

fn setSockFlags(sock: socket_t, flags: u32) !void {
    if ((flags & SOCK.CLOEXEC) != 0) {
        if (native_os == .windows) {
            // TODO: Find out if this is supported for sockets
        } else {
            var fd_flags = fcntl(sock, F.GETFD, 0) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
            fd_flags |= FD_CLOEXEC;
            _ = fcntl(sock, F.SETFD, fd_flags) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
        }
    }
    if ((flags & SOCK.NONBLOCK) != 0) {
        if (native_os == .windows) {
            var mode: c_ulong = 1;
            if (windows.ws2_32.ioctlsocket(sock, windows.ws2_32.FIONBIO, &mode) == windows.ws2_32.SOCKET_ERROR) {
                switch (windows.ws2_32.WSAGetLastError()) {
                    .WSANOTINITIALISED => unreachable,
                    .WSAENETDOWN => return error.NetworkSubsystemFailed,
                    .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                    // TODO: handle more errors
                    else => |err| return windows.unexpectedWSAError(err),
                }
            }
        } else {
            var fl_flags = fcntl(sock, F.GETFL, 0) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
            fl_flags |= 1 << @bitOffsetOf(O, "NONBLOCK");
            _ = fcntl(sock, F.SETFL, fl_flags) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
        }
    }
}

/// Test whether a file descriptor refers to a terminal.
pub fn isatty(handle: fd_t) bool {
    if (builtin.link_libc) {
        return system.isatty(handle) != 0;
    }
    return system.isatty(handle) != 0;
}

pub fn tcgetattr(handle: fd_t) posix.TermiosGetError!posix.termios {
    while (true) {
        var term: posix.termios = undefined;
        switch (errno(system.tcgetattr(handle, &term))) {
            .SUCCESS => return term,
            .INTR => continue,
            .BADF => unreachable,
            .NOTTY => return error.NotATerminal,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub fn tcsetattr(handle: fd_t, optional_action: posix.TCSA, termios_p: posix.termios) posix.TermiosSetError!void {
    while (true) {
        switch (errno(system.tcsetattr(handle, optional_action, &termios_p))) {
            .SUCCESS => return,
            .BADF => unreachable,
            .INTR => continue,
            .INVAL => unreachable,
            .NOTTY => return error.NotATerminal,
            .IO => return error.ProcessOrphaned,
            else => |err| return unexpectedErrno(err),
        }
    }
}

/// initialize an inotify instance
pub fn inotify_init1(flags: u32) anyerror!i32 {
    const rc = system.inotify_init1(flags);
    switch (errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .INVAL => unreachable,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOMEM => return error.SystemResources,
        else => |err| return unexpectedErrno(err),
    }
}

const timespec = posix.timespec;
/// From `std.os.wasi`, not `system`: `std.c` has no `timestamp_t`, and the only
/// use below is the wasi-without-libc branch of `clock_gettime`.
pub const timestamp_t = std.os.wasi.timestamp_t;
const clockid_t = system.clockid_t;

pub const ClockGetTimeError = error{UnsupportedClock} || UnexpectedError;

pub fn clock_gettime(clock_id: clockid_t) ClockGetTimeError!timespec {
    var tp: timespec = undefined;

    if (native_os == .windows) {
        @compileError("Windows does not support POSIX; use Windows-specific API or cross-platform std.time API");
    } else if (native_os == .wasi and !builtin.link_libc) {
        var ts: timestamp_t = undefined;
        switch (system.clock_time_get(clock_id, 1, &ts)) {
            .SUCCESS => {
                tp = .{
                    .sec = @intCast(ts / std.time.ns_per_s),
                    .nsec = @intCast(ts % std.time.ns_per_s),
                };
            },
            .INVAL => return error.UnsupportedClock,
            else => |err| return unexpectedErrno(err),
        }
        return tp;
    }

    switch (errno(system.clock_gettime(clock_id, &tp))) {
        .SUCCESS => return tp,
        .FAULT => unreachable,
        .INVAL => return error.UnsupportedClock,
        else => |err| return unexpectedErrno(err),
    }
}
