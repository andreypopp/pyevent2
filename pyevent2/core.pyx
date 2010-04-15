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
"""Wrappers around libevent 2.x API.

This module provides a mechanism to execute a function when a
specific event on a file handle, file descriptor, or signal occurs,
or after a given time has passed.

The code is based on pyevent_ and gevent_.

.. _pyevent: http://code.google.com/p/pyevent/
.. _gevent: http://gevent.org/
"""

import sys
import traceback

__all__ = ["get_version",
           "Base",
           "Event",
           "ReadEvent",
           "WriteEvent",
           "ReadWriteEvent",
           "TimerEvent",
           "SignalEvent"]


ctypedef void (*event_handler)(int fd, short evtype, void *arg)


cdef extern from "errno.h":
    int errno


cdef extern from "string.h":
    char* strerror(int errnum)


cdef extern from "Python.h":

    void Py_INCREF(object o)
    void Py_DECREF(object o)


cdef extern from "event.h":

    int EV_TIMEOUT
    int EV_READ
    int EV_WRITE
    int EV_SIGNAL
    int EV_PERSIST
    int EVLOOP_NONBLOCK
    int EVLOOP_ONCE

    struct timeval:
        long int tv_sec
        long int tv_usec

    struct event_base:
        pass

    struct event:
        pass

    event_base* event_base_new()
    int event_base_loop(event_base* eb, int flags) nogil
    int event_base_dispatch(event_base* eb) nogil
    char* event_base_get_method(event_base *eb)

    event* event_new(event_base* eb, int fd, short evtype,
                     event_handler handler, void *args)
    void event_free(event *ev)
    void event_active(event *ev, short evtype, short ncalls)
    int event_add(event *ev, timeval *tv)
    int event_del(event *ev)
    int event_pending(event *ev, short evtype, timeval *tv)

    char* event_get_version()


def get_version():
    """Return used libevent version."""
    return event_get_version()


cdef class Base:
    """Event base object."""

    cdef event_base *eb

    def __init__(self):
        """Initialize event base."""
        self.eb = event_base_new()

    property method:

        def __get__(self):
            return event_base_get_method(self.eb)

    def dispatch(self):
        """Dispatch all events on the event queue.
        Returns 0 on success, and 1 if no events are registered.
        May raise IOError.
        """
        cdef int ret
        with nogil:
            ret = event_base_dispatch(self.eb)
        if ret < 0:
            raise IOError(errno, strerror(errno))
        return ret

    def loop(self, nonblock=False):
        """Dispatch all pending events on queue in a single pass.
        Returns 0 on success, and 1 if no events are registered.
        May raise IOError.
        """
        cdef int flags
        cdef int ret
        flags = EVLOOP_ONCE
        if nonblock:
            flags = flags|EVLOOP_NONBLOCK
        with nogil:
            ret = event_base_loop(self.eb, flags)
        if ret < 0:
            raise IOError(errno, strerror(errno))
        return ret

    def event(self, *args, **kwargs):
        return Event(self, *args, **kwargs)

    def read(self, *args, **kwargs):
        return ReadEvent(self, *args, **kwargs)

    def write(self, *args, **kwargs):
        return WriteEvent(self, *args, **kwargs)

    def read_write(self, *args, **kwargs):
        return ReadWriteEvent(self, *args, **kwargs)

    def timer(self, *args, **kwargs):
        return TimerEvent(self, *args, **kwargs)

    def signal(self, *args, **kwargs):
        return SignalEvent(self, *args, **kwargs)

    def active_event(self, *args, **kwargs):
        return ActiveEvent(self, *args, **kwargs)


cdef class Event:
    """Event object with a user callback.

    Callback is called as `callback(event, event_type, arg)`, where `event` is
    current event instance and `event_type` is why event was happened.
    """

    cdef event *ev
    cdef object callback
    cdef object arg

    def __init__(self, Base eb, short evtype, int handle,
                 callback, arg=None):
        self.callback = callback
        self.arg = arg
        cdef void* c_self = <void*>self
        self.ev = event_new(eb.eb, handle, evtype, __event_handler, c_self)

    property pending:
        """Return True if the event is still scheduled to run."""

        def __get__(self):
            return event_pending(
                self.ev, EV_TIMEOUT|EV_SIGNAL|EV_READ|EV_WRITE, NULL)

    def add(self, timeout=-1):
        """Add event to be executed after an optional *timeout* - number of
        seconds after which the event will be executed."""
        cdef timeval tv
        cdef double c_timeout
        cdef int result
        if not self.pending:
            Py_INCREF(self)
        if timeout >= 0.0:
            c_timeout = <double>timeout
            tv.tv_sec = <long>c_timeout
            tv.tv_usec = <long>((c_timeout - <double>tv.tv_sec) * 1000000.0)
            result = event_add(self.ev, &tv)
        else:
            result = event_add(self.ev, NULL)
        if result < 0:
            raise IOError(errno, strerror(errno))

    def cancel(self):
        """Remove event from the event queue."""
        cdef int result
        if self.pending:
            result = event_del(self.ev)
            event_free(self.ev)
            if result < 0:
                return result
            Py_DECREF(self)
            return result

    def __enter__(self):
        return self

    def __exit__(self, *exit_args):
        self.cancel()


cdef class ReadEvent(Event):
    """Create a new scheduled event with evtype=EV_READ"""

    def __init__(self, Base eb, int handle, callback, timeout=-1, arg=None):
        Event.__init__(self, eb, EV_READ, handle, callback, arg=arg)
        self.add(timeout)


cdef class WriteEvent(Event):
    """Create a new scheduled event with evtype=EV_WRITE"""

    def __init__(self, Base eb, int handle, callback, timeout=-1, arg=None):
        Event.__init__(self, eb, EV_WRITE, handle, callback, arg=arg)
        self.add(timeout)


cdef class ReadWriteEvent(Event):
    """Create a new scheduled event with evtype=EV_READ|EV_WRITE"""

    def __init__(self, Base, eb, int handle, callback, timeout=-1, arg=None):
        Event.__init__(self, eb, EV_READ|EV_WRITE, handle, callback, arg=arg)
        self.add(timeout)


cdef class TimerEvent(Event):
    """Create a new scheduled timer event."""

    def __init__(self, Base eb, float seconds, callback, arg=None):
        Event.__init__(self, eb, EV_TIMEOUT, -1, callback, arg=arg)
        self.add(seconds)


cdef class SignalEvent(Event):
    """Create a new persistent signal event."""

    def __init__(self, Base eb, int signalnum, callback, arg=None):
        Event.__init__(self, eb, EV_SIGNAL|EV_PERSIST, signalnum, callback, arg)
        self.add(-1)


cdef class ActiveEvent(Event):
    """An event that is scheduled to run in the current loop iteration"""

    def __init__(self, Base eb, callback, arg=None):
        Event.__init__(self, eb, EV_TIMEOUT, -1, callback, arg=arg)
        event_active(self.ev, EV_TIMEOUT, 1)

    def add(self, timeout=-1):
        pass


cdef void __event_handler(int fd, short evtype, void *arg) with gil:
    """Wrapper for event handlers."""
    cdef Event ev = <Event>arg
    try:
        ev.callback(ev, evtype, ev.arg)
    except:
        traceback.print_exc()
        try:
            sys.stderr.write('Failed to execute callback for %s\n\n' % (ev, ))
        except:
            traceback.print_exc()
    finally:
        if not ev.pending:
            Py_DECREF(ev)
