import crc32c

x = crc32c.crc32c(b'\0')
print(hex(x), "of type", type(x))
