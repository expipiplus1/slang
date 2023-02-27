import gdb.printing

class SlangListPrinter:
    class _iterator:
        def __init__ (self, buf, count):
            self.buf = buf
            self.count = count
            self.i = 0

        def __iter__(self):
            return self

        def __next__(self):
            if self.i == self.count:
                raise StopIteration
            n = '[%d]' % self.i
            x = (self.buf + self.i).dereference()
            self.i = self.i + 1
            return (n, x)

    def __init__(self, val):
        self.typename = val.type
        self.val = val

    def children(self):
        return self._iterator(self.val['m_buffer'], self.val['m_count'])

    def to_string(self):
        capacity = self.val['m_capacity']
        count = self.val['m_count']
        return ('%s of length %d, capacity %d' % (self.typename, count, capacity))

pp = gdb.printing.RegexpCollectionPrettyPrinter('Slang')
pp.add_printer('List', '^Slang::List<.*>$', SlangListPrinter)
gdb.printing.register_pretty_printer(gdb.current_objfile(), pp)
