#!/usr/sbin/dtrace -Cs

#pragma D option quiet
#pragma D option switchrate=10hz
#pragma D option dynvarsize=16m
#pragma D option bufsize=16m
#pragma D option strsize=1024

inline int af_inet = 2 /*AF_INET*/;
inline int af_inet6 = 28 /*AF_INET6*/;

/* Options to enable/disable instrumentation */
#define AUDIT_PRINT_VALID_FLAGS 1
#define AUDIT_ALL_CALLS 0
#define AUDIT_FAILED_CALLS 0
#define AUDIT_ANON_MMAP 0
#define AUDIT_SSH_MORE 0

/* FROM security/audit/audit_private.h
 *
 * Arguments in the audit record are initially not defined; flags are set to
 * indicate if they are present so they can be included in the audit log
 * stream only if defined.
 */
#define	ARG_EUID		0x0000000000000001ULL
#define	ARG_RUID		0x0000000000000002ULL
#define	ARG_SUID		0x0000000000000004ULL
#define	ARG_EGID		0x0000000000000008ULL
#define	ARG_RGID		0x0000000000000010ULL
#define	ARG_SGID		0x0000000000000020ULL
#define	ARG_PID			0x0000000000000040ULL
#define	ARG_UID			0x0000000000000080ULL
#define	ARG_AUID		0x0000000000000100ULL
#define	ARG_GID			0x0000000000000200ULL
#define	ARG_FD			0x0000000000000400ULL
#define	ARG_POSIX_IPC_PERM	0x0000000000000800ULL
#define	ARG_FFLAGS		0x0000000000001000ULL
#define	ARG_MODE		0x0000000000002000ULL
#define	ARG_DEV			0x0000000000004000ULL
#define	ARG_ADDR		0x0000000000008000ULL
#define	ARG_LEN			0x0000000000010000ULL
#define	ARG_MASK		0x0000000000020000ULL
#define	ARG_SIGNUM		0x0000000000040000ULL
#define	ARG_LOGIN		0x0000000000080000ULL
#define	ARG_SADDRINET		0x0000000000100000ULL
#define	ARG_SADDRINET6		0x0000000000200000ULL
#define	ARG_SADDRUNIX		0x0000000000400000ULL
#define	ARG_TERMID_ADDR		0x0000000000400000ULL
#define	ARG_UNUSED2		0x0000000001000000ULL
#define	ARG_UPATH1		0x0000000002000000ULL
#define	ARG_UPATH2		0x0000000004000000ULL
#define	ARG_TEXT		0x0000000008000000ULL
#define	ARG_VNODE1		0x0000000010000000ULL
#define	ARG_VNODE2		0x0000000020000000ULL
#define	ARG_SVIPC_CMD		0x0000000040000000ULL
#define	ARG_SVIPC_PERM		0x0000000080000000ULL
#define	ARG_SVIPC_ID		0x0000000100000000ULL
#define	ARG_SVIPC_ADDR		0x0000000200000000ULL
#define	ARG_GROUPSET		0x0000000400000000ULL
#define	ARG_CMD			0x0000000800000000ULL
#define	ARG_SOCKINFO		0x0000001000000000ULL
#define	ARG_ASID		0x0000002000000000ULL
#define	ARG_TERMID		0x0000004000000000ULL
#define	ARG_AUDITON		0x0000008000000000ULL
#define	ARG_VALUE		0x0000010000000000ULL
#define	ARG_AMASK		0x0000020000000000ULL
#define	ARG_CTLNAME		0x0000040000000000ULL
#define	ARG_PROCESS		0x0000080000000000ULL
#define	ARG_MACHPORT1		0x0000100000000000ULL
#define	ARG_MACHPORT2		0x0000200000000000ULL
#define	ARG_EXIT		0x0000400000000000ULL
#define	ARG_IOVECSTR		0x0000800000000000ULL
#define	ARG_ARGV		0x0001000000000000ULL
#define	ARG_ENVV		0x0002000000000000ULL
#define	ARG_ATFD1		0x0004000000000000ULL
#define	ARG_ATFD2		0x0008000000000000ULL
#define	ARG_RIGHTS		0x0010000000000000ULL
#define	ARG_FCNTL_RIGHTS	0x0020000000000000ULL
/* Gap:				0x0040000000000000ULL */
#define	ARG_OBJUUID1		0x0080000000000000ULL
#define	ARG_OBJUUID2		0x0100000000000000ULL
#define	ARG_NONE		0x0000000000000000ULL
#define	ARG_ALL			0xFFFFFFFFFFFFFFFFULL

#define	RET_OBJUUID1		0x0000000000000001ULL
#define	RET_OBJUUID2		0x0000000000000002ULL

#define	ARG_IS_VALID(arg)	(args[1]->ar_valid_arg & (arg))
#define	RET_IS_VALID(ret)	(args[1]->ar_valid_ret & (ret))


/*
 * UUIDS fields:
 * ar_subj_uuid: always the UUID of the process performing/authorizing the system call
 *  ar_arg_procuuid: UUID of a target process being operated on, or in the case of fork(2), the child process
 * ar_arg_objuuid1 and ar_arg_objuuid2: the optional first (and further optional second) UUIDs of other types of objects being operated on. Almost always vnode/pipe/socket UUIDs, but in the future presumably also other IPC types
 */

/* Convenience macro for printing audit fields */
#define sprint_audit_string(flag, field, name) \
	ARG_IS_VALID(flag)?strjoin( strjoin(strjoin(", \"", #name), "\": \""), strjoin(stringof(args[1]->field),"\"")):""
#define sprint_audit_int(flag, field, name) \
	ARG_IS_VALID(flag)?strjoin( strjoin(strjoin(", \"", #name), "\": "), lltostr(args[1]->field)):""
#define sprint_audit_ret_uuid(flag, field, name)			\
	RET_IS_VALID(flag)?strjoin( strjoin(strjoin(", \"", #name), "\": \""), strjoin(uuidtostr((uintptr_t)&args[1]->field),"\"")):""
#define sprint_audit_arg_uuid(flag, field, name)			\
	ARG_IS_VALID(flag)?strjoin( strjoin(strjoin(", \"", #name), "\": \""), strjoin(uuidtostr((uintptr_t)&args[1]->field),"\"")):""



/*
 * BEGIN and END probes
 */
BEGIN {
    printf("[\n");
    comma=" ";
}

END {
  printf("]\n");
}

/* XXX: proc_filter */
/* Default filter on processes */
#define proc_filter_def (pid != $pid)
/* Filter on processes for read/write/mmap */
#define proc_filter_rw (pid != $pid) && (execname != "sshd") && \
	(execname != "tmux") && (execname != "moused")

#if AUDIT_ALL_CALLS
audit::aue_*:commit
#else
audit::aue_fork:commit,audit::aue_vfork:commit,audit::aue_rfork:commit,
audit::aue_fexecve:commit,audit::aue_exec:commit,audit::aue_execve:commit,
audit::aue_exit:commit,
audit::aue_open_*:commit,audit::aue_openat_*:commit,
audit::aue_dup*:commit,
audit::aue_close*:commit,
audit::aue_rename*:commit,
audit::aue_unlink*:commit,
audit::aue_truncate:commit,audit::aue_ftruncate:commit,
audit::aue_*read:commit,audit::aue_readl:commit,
audit::aue_*readv:commit,audit::aue_readvl:commit,
audit::aue_write:commit,audit::aue_pwrite:commit,audit::aue_writev:commit,audit::aue_writel:commit,audit::aue_writevl:commit,
audit::aue_mmap:commit,
audit::aue_connect*:commit,
audit::aue_accept*:commit,
audit::aue_setuid:commit,audit::aue_setgid:commit,audit::aue_seteuid:commit,audit::aue_setegid:commit,
audit::aue_setreuid:commit,audit::aue_setregid:commit,
audit::aue_setresuid:commit,audit::aue_setresgid:commit,
audit::aue_pipe*:commit,
audit::aue_recvfrom:commit,
audit::aue_recvmsg:commit,
audit::aue_chdir:commit,
audit::aue_fchdir:commit,
audit::aue_chmod:commit,
audit::aue_lchmod:commit,
audit::aue_fchmod:commit,
audit::aue_fchmodat:commit,
audit::aue_chown:commit,
audit::aue_lchown:commit,
audit::aue_fchown:commit,
audit::aue_fcntl:commit,
audit::aue_link*:commit,
audit::aue_lseek:commit,
audit::aue_mkdir*:commit,
audit::aue_rmdir:commit,
audit::aue_sendto:commit,
audit::aue_sendmsg:commit,
audit::aue_socket:commit,
audit::aue_socketpair:commit,
audit::aue_symlink*:commit,
audit::aue_umask:commit,
audit::aue_utimes:commit,
audit::aue_lutimes:commit,
audit::aue_futimes*:commit
#endif
/(pid != $pid)
#if !AUDIT_FAILED_CALLS
    && (args[1]->ar_retval >= 0)
#endif
#if !AUDIT_ANON_MMAP
    && (args[1]->ar_arg_fd != -1)
#endif
#if !AUDIT_SSH_MORE
    && ((execname != "sshd") || ((execname == "sshd") &&
	(probefunc != "aue_read") && (probefunc != "aue_write") && (probefunc != "aue_mmap")))
#endif
/
{
    printf("%s {\"event\": \"%s:%s:%s:\", \"time\": %d, \"pid\": %d, \"ppid\": %d, \"tid\": %d, \"uid\": %d, \"exec\": \"%s\", \"subjuuid\": \"%U\"", comma, probeprov, probemod, probefunc, walltimestamp, pid, ppid, tid, uid, args[1]->ar_subj_comm, args[1]->ar_subj_uuid);
    printf("%s",
	sprint_audit_arg_uuid(ARG_OBJUUID1, ar_arg_objuuid1, arg_objuuid1));
    printf("%s",
	sprint_audit_arg_uuid(ARG_OBJUUID2, ar_arg_objuuid2, arg_objuuid2));
    printf("%s",
	sprint_audit_ret_uuid(RET_OBJUUID1, ar_ret_objuuid1, ret_objuuid1));
    printf("%s",
	sprint_audit_ret_uuid(RET_OBJUUID2, ar_ret_objuuid1, ret_objuuid2));
    printf("%s",
	sprint_audit_int(ARG_PID, ar_arg_pid, arg_pid));
    printf("%s",
	sprint_audit_int(ARG_EUID, ar_arg_euid, arg_euid));
    printf("%s",
	sprint_audit_int(ARG_RUID, ar_arg_ruid, arg_ruid));
    printf("%s",
	sprint_audit_int(ARG_SUID, ar_arg_suid, arg_suid));
    printf("%s",
	sprint_audit_int(ARG_UID, ar_arg_uid, arg_uid));
    printf("%s",
	sprint_audit_int(ARG_EGID, ar_arg_egid, arg_egid));
    printf("%s",
	sprint_audit_int(ARG_RGID, ar_arg_rgid, arg_rgid));
    printf("%s",
	sprint_audit_int(ARG_SGID, ar_arg_sgid, arg_sgid));
    printf("%s",
	sprint_audit_int(ARG_GID, ar_arg_gid, arg_gid));
    printf("%s",
	sprint_audit_string(ARG_UPATH1, ar_arg_upath1, upath1));
    printf("%s",
	sprint_audit_string(ARG_UPATH2, ar_arg_upath2, upath2));
    printf("%s",
	sprint_audit_int(ARG_FFLAGS, ar_arg_fflags, flags));
    printf("%s",
	sprint_audit_int(ARG_FD, ar_arg_fd, fd));
    printf("%s",
	sprint_audit_int(ARG_ATFD1, ar_arg_atfd1, atfd1));
    printf("%s",
	sprint_audit_int(ARG_ATFD2, ar_arg_atfd2, atfd2));
    printf("%s",
	sprint_audit_int(ARG_MODE, ar_arg_mode, mode));
    printf("%s",
	sprint_audit_int(ARG_LEN, ar_arg_len, len));
    printf("%s",
	sprint_audit_int(ARG_SIGNUM, ar_arg_signum, signum));

    printf("%s",
	ARG_IS_VALID(ARG_SADDRINET)?
	strjoin(", \"address\": \"", strjoin(
	    inet_ntop(af_inet,(void*)&((struct sockaddr_in*) &args[1]->ar_arg_sockaddr)->sin_addr), "\""))
	:ARG_IS_VALID(ARG_SADDRINET6)?
	strjoin(", \"address\": \"", strjoin(
	    inet_ntoa6(&((struct sockaddr_in6*) &args[1]->ar_arg_sockaddr)->sin6_addr), "\""))
	:ARG_IS_VALID(ARG_SADDRUNIX)?
	strjoin(", \"address\": \"", strjoin(
		((struct sockaddr_un*) &args[1]->ar_arg_sockaddr)->sun_path, "\""))
	:"");

    printf("%s",
	ARG_IS_VALID(ARG_SADDRINET)?
	strjoin(", \"port\": ", lltostr(ntohs(((struct sockaddr_in*) &args[1]->ar_arg_sockaddr)->sin_port)))
        :ARG_IS_VALID(ARG_SADDRINET6)?
	strjoin(", \"port\": ", lltostr(ntohs(((struct sockaddr_in6*) &args[1]->ar_arg_sockaddr)->sin6_port)))
	: "");

#if AUDIT_PRINT_VALID_FLAGS
    printf(", \"valid_arg\": 0x%016x, \"valid_ret\": 0x%016x",
	    args[1]->ar_valid_arg, args[1]->ar_valid_ret);
#endif
    printf(", \"retval\": %d", args[1]->ar_retval);
    printf(", \"errno\": %d", args[1]->ar_errno);

    printf("}\n");
    comma=",";
}