"""Tests for pyevent2.core."""

import unittest

from pyevent2 import core

__all__ = ["TestReadEvent",
           "TestWriteEvent"]


class TestBase(unittest.TestCase):

    def setUp(self):
        self.base = core.Base()


class TestReadEvent(TestBase):

    HOST = "localhost"
    PORT = 33333

    def setUp(self):
        TestBase.setUp(self)
        self.data = ""

    def server(self):
        import socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setblocking(0)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((self.HOST, self.PORT))
        sock.listen(1)
        self.base.read(sock.fileno(), self.accept, -1, sock)

    def accept(self, event, evtype, arg):
        sock = arg
        conn, addr = sock.accept()
        sock.close()
        self.base.read(conn.fileno(), self.recv, -1, conn)

    def recv(self, event, evtype, arg):
        conn = arg
        recvd = conn.recv(4)
        if recvd:
            self.data += recvd
            self.base.read(conn.fileno(), self.recv, -1, conn)
        else:
            conn.close()

    def client(self):
        import socket
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((self.HOST, self.PORT))
        s.send("Hello, world")
        s.close()

    def test_it(self):
        self.server()
        import threading
        writer = threading.Thread(target=self.client)
        writer.start()
        self.base.dispatch()
        writer.join()
        self.assertEqual(self.data, "Hello, world")


class TestWriteEvent(TestBase):

    HOST = "localhost"
    PORT = 33333

    def setUp(self):
        TestBase.setUp(self)
        self.data = ""

    def server(self):
        import socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setblocking(0)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((self.HOST, self.PORT))
        sock.listen(1)
        self.base.read(sock.fileno(), self.accept, -1, sock)

    def accept(self, event, evtype, arg):
        sock = arg
        conn, addr = sock.accept()
        sock.close()
        self.base.write(conn.fileno(), self.send, -1, (conn, "Hello, world"))

    def send(self, event, evtype, arg):
        conn, tosend = arg
        if tosend:
            conn.send(tosend[:3])
            tosend = tosend[3:]
            self.base.write(conn.fileno(), self.send, -1, (conn, tosend))
        else:
            conn.close()

    def client(self):
        import socket
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((self.HOST, self.PORT))
        while True:
            recvd = s.recv(4)
            if recvd:
                self.data += recvd
            else:
                break
        s.close()

    def test_it(self):
        self.server()
        import threading
        writer = threading.Thread(target=self.client)
        writer.start()
        self.base.dispatch()
        writer.join()
        self.assertEqual(self.data, "Hello, world")


class TestReadWriteEventRead(TestBase):

    HOST = "localhost"
    PORT = 33333

    def setUp(self):
        TestBase.setUp(self)
        self.data = ""

    def server(self):
        import socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setblocking(0)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((self.HOST, self.PORT))
        sock.listen(1)
        self.base.read_write(sock.fileno(), self.accept, -1, sock)

    def accept(self, event, evtype, arg):
        sock = arg
        conn, addr = sock.accept()
        sock.close()
        self.base.read_write(conn.fileno(), self.recv, -1, conn)

    def recv(self, event, evtype, arg):
        conn = arg
        recvd = conn.recv(4)
        if recvd:
            self.data += recvd
            self.base.read_write(conn.fileno(), self.recv, -1, conn)
        else:
            conn.close()

    def client(self):
        import socket
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((self.HOST, self.PORT))
        s.send("Hello, world")
        s.close()

    def test_it(self):
        self.server()
        import threading
        writer = threading.Thread(target=self.client)
        writer.start()
        self.base.dispatch()
        writer.join()
        self.assertEqual(self.data, "Hello, world")


class TestReadWriteEventWrite(TestBase):

    HOST = "localhost"
    PORT = 33333

    def setUp(self):
        TestBase.setUp(self)
        self.data = ""

    def server(self):
        import socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setblocking(0)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((self.HOST, self.PORT))
        sock.listen(1)
        self.base.read_write(sock.fileno(), self.accept, -1, sock)

    def accept(self, event, evtype, arg):
        sock = arg
        conn, addr = sock.accept()
        sock.close()
        self.base.read_write(
            conn.fileno(), self.send, -1, (conn, "Hello, world"))

    def send(self, event, evtype, arg):
        conn, tosend = arg
        if tosend:
            conn.send(tosend[:3])
            tosend = tosend[3:]
            self.base.read_write(conn.fileno(), self.send, -1, (conn, tosend))
        else:
            conn.close()

    def client(self):
        import socket
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((self.HOST, self.PORT))
        while True:
            recvd = s.recv(4)
            if recvd:
                self.data += recvd
            else:
                break
        s.close()

    def test_it(self):
        self.server()
        import threading
        writer = threading.Thread(target=self.client)
        writer.start()
        self.base.dispatch()
        writer.join()
        self.assertEqual(self.data, "Hello, world")
