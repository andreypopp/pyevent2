#
# libevent 2.x Python bindings
#
# Copyright (c) 2004 Dug Song <dugsong@monkey.org>
# Copyright (c) 2003 Martin Murray <murrayma@citi.umich.edu>
# Copyright (c) 2009-2010 Denis Bilenko <denis.bilenko@gmail.com>
# Copyright (c) 2010 Andrey Popp <8mayday@gmail.com>
#
# Licensed under BSD license.
#
"""Wrappers around libevent 2.x DNS API."""

cdef extern from "Python.h":
    object PyString_FromStringAndSize(char *v, int len)
    object PyString_FromString(char *v)


cdef extern from "event.h":

    ctypedef void (*evdns_callback)(int result,
                                    char t,
                                    int count,
                                    int ttl,
                                    void *addrs,
                                    void *arg)

    struct evdns_base:
        pass

    struct evdns_request:
        pass

    evdns_base* evdns_base_new(event_base *eb, int init_nameservers)
    void evdns_base_free(evdns_base *db)
    evdns_request* evdns_base_resolve_ipv4(evdns_base *db,
                                           char *name,
                                           int flags,
                                           evdns_callback callback,
                                           void *ptr)
    evdns_request* evdns_base_resolve_ipv6(evdns_base *db,
                                           char *name,
                                           int flags,
                                           evdns_callback callback,
                                           void *ptr)
    evdns_request* evdns_base_resolve_reverse(evdns_base *db,
                                              void *ip,
                                              int flags,
                                              evdns_callback callback,
                                              void *arg)
    evdns_request* evdns_base_resolve_reverse_ipv6(evdns_base *db,
                                                   void *ip,
                                                   int flags,
                                                   evdns_callback callback,
                                                   void *arg)


# Result codes
DNS_ERR_NONE         = 0
DNS_ERR_FORMAT       = 1
DNS_ERR_SERVERFAILED = 2
DNS_ERR_NOTEXIST     = 3
DNS_ERR_NOTIMPL      = 4
DNS_ERR_REFUSED      = 5
DNS_ERR_TRUNCATED    = 65
DNS_ERR_UNKNOWN      = 66
DNS_ERR_TIMEOUT      = 67
DNS_ERR_SHUTDOWN     = 68

# Types
DNS_IPv4_A    = 1
DNS_PTR       = 2
DNS_IPv6_AAAA = 3

# Flags
DNS_QUERY_NO_SEARCH = 1


cdef class DNSBase:

    cdef evdns_base *db

    def __cinit__(self, Base eb):
        self.db = evdns_base_new(eb.eb, 1)

    def __dealloc__(self):
        if self.db != NULL:
            evdns_base_free(self.db)
        self.db = NULL

    def resolve_ipv4(self, char *name, int flags, object callback):
        """Resolve domain to IPv4 address."""
        cdef evdns_request *req = evdns_base_resolve_ipv4(self.db, name, flags,
                                                          __evdns_callback,
                                                          <void *>callback)
        if req == NULL:
            raise IOError(
                "evdns_resolve_ipv4(%r, %r) returned %s" % (
                    name, flags))
        Py_INCREF(callback)

    def resolve_ipv6(self, char *name, int flags, object callback):
        """Resolve domain to IPv6 address."""
        cdef evdns_request *req = evdns_base_resolve_ipv6(self.db, name, flags,
                                                          __evdns_callback,
                                                          <void *>callback)
        if req == NULL:
            raise IOError(
                "evdns_resolve_ipv4(%r, %r) returned %s" % (
                    name, flags))
        Py_INCREF(callback)

    def resolve_reverse(self, char* packed_ip,
                            int flags, object callback):
        """Lookup a PTR record for a given IPv4 address."""
        cdef evdns_request *req = evdns_base_resolve_reverse(
            self.db, <void *>packed_ip, flags, __evdns_callback,
            <void *>callback)
        if req == NULL:
            raise IOError('evdns_resolve_reverse(%r, %r)' % (packed_ip, flags))
        Py_INCREF(callback)

    def resolve_reverse_ipv6(self, char* packed_ip,
                                 int flags, object callback):
        """Lookup a PTR record for a given IPv6 address."""
        cdef evdns_request *req = evdns_base_resolve_reverse_ipv6(
            self.db, <void *>packed_ip, flags, __evdns_callback,
            <void *>callback)
        if req == NULL:
            raise IOError('evdns_resolve_reverse_ipv6(%r, %r)' % (
                packed_ip, flags))
        Py_INCREF(callback)


cdef void __evdns_callback(int code, char type, int count, int ttl,
                           void *addrs, void *arg) with gil:
    cdef int i
    cdef object callback = <object>arg
    Py_DECREF(callback)
    cdef object addr
    cdef object result

    if type == DNS_IPv4_A:
        result = []
        for i from 0 <= i < count:
            addr = PyString_FromStringAndSize(&(<char *>addrs)[i*4], 4)
            result.append(addr)
    elif type == DNS_IPv6_AAAA:
        result = []
        for i from 0 <= i < count:
            addr = PyString_FromStringAndSize(&(<char *>addrs)[i*16], 16)
            result.append(addr)
    elif type == DNS_PTR and count == 1: # only 1 PTR possible
        result = PyString_FromString((<char **>addrs)[0])
    else:
        result = None
    try:
        callback(code, type, ttl, result)
    except:
        traceback.print_exc()
