from libc.stdlib cimport malloc, free

HEADER_ZLIB_DICT = \
	b"optionsgetheadpostputdeletetraceacceptaccept-charsetaccept-encodingaccept-" \
	b"languageauthorizationexpectfromhostif-modified-sinceif-matchif-none-matchi" \
	b"f-rangeif-unmodifiedsincemax-forwardsproxy-authorizationrangerefererteuser" \
	b"-agent10010120020120220320420520630030130230330430530630740040140240340440" \
	b"5406407408409410411412413414415416417500501502503504505accept-rangesageeta" \
	b"glocationproxy-authenticatepublicretry-afterservervarywarningwww-authentic" \
	b"ateallowcontent-basecontent-encodingcache-controlconnectiondatetrailertran" \
	b"sfer-encodingupgradeviawarningcontent-languagecontent-lengthcontent-locati" \
	b"oncontent-md5content-rangecontent-typeetagexpireslast-modifiedset-cookieMo" \
	b"ndayTuesdayWednesdayThursdayFridaySaturdaySundayJanFebMarAprMayJunJulAugSe" \
	b"pOctNovDecchunkedtext/htmlimage/pngimage/jpgimage/gifapplication/xmlapplic" \
	b"ation/xhtmltext/plainpublicmax-agecharset=iso-8859-1utf-8gzipdeflateHTTP/1" \
	b".1statusversionurl\x00"

cdef extern from "zlib.h":

	ctypedef void *voidp
	ctypedef voidp (*alloc_func)(voidp opaque, unsigned int items, unsigned int size)
	ctypedef void (*free_func)(voidp opaque, voidp address)

	cdef enum flush_method:
		Z_NO_FLUSH = 0
		Z_SYNC_FLUSH = 2
	
	cdef enum flate_status:
		Z_OK = 0
		Z_STREAM_END = 1
		Z_NEED_DICT = 2 

	ctypedef struct z_stream:
		unsigned char *next_in
		unsigned int avail_in

		unsigned char *next_out
		unsigned int avail_out
	
		alloc_func zalloc
		free_func zfree

	int deflateInit(z_stream *strm, int level)
	int inflateInit(z_stream *strm)

	int deflate(z_stream *strm, flush_method flush)
	int inflate(z_stream *strm, flush_method flush)

	int deflateEnd(z_stream *strm)
	int inflateEnd(z_stream *strm)

	int deflateSetDictionary(z_stream *strm, unsigned char *dictionary, unsigned int dictLength)
	int inflateSetDictionary(z_stream *strm, unsigned char *dictionary, unsigned int dictLength)

cdef class Stream(object):
	cdef z_stream *_stream
	def __init__(self):
		self._stream = <z_stream *>malloc(sizeof(z_stream))
		self._stream.next_out = <unsigned char*>NULL
		self._stream.avail_out = 0
		self._stream.zalloc = NULL
		self._stream.zfree = NULL

cdef class Deflater(Stream):
	def __init__(self, level=6):
		Stream.__init__(self)
		deflateInit(self._stream, level)
		deflateSetDictionary(self._stream, HEADER_ZLIB_DICT, len(HEADER_ZLIB_DICT))

	def __dealloc__(self):
		deflateEnd(self._stream)
		free(self._stream)

	def compress(self, chunk):
		self._stream.next_in = chunk
		self._stream.avail_in = len(chunk)

		buf = bytearray()
		chunk_len = 1024 * 64

		while True:
			out = bytes(chunk_len)
			self._stream.next_out = out
			self._stream.avail_out = chunk_len

			status = deflate(self._stream, Z_SYNC_FLUSH)
			boundary = chunk_len - self._stream.avail_out
			buf.extend(out[:boundary])

			if status == Z_STREAM_END or self._stream.avail_in == 0: 
				break
			elif status != Z_OK:
				raise AssertionError(status)

		return bytes(buf)

cdef class Inflater(Stream):

	def __init__(self):
		Stream.__init__(self)
		inflateInit(self._stream)

	def __dealloc__(self):
		inflateEnd(self._stream)
		free(self._stream)

	def decompress(self, chunk):
		self._stream.next_in = chunk
		self._stream.avail_in = len(chunk)
			
		buf = bytearray()
		chunk_len = 1024 * 64

		while True:
			out = bytes(chunk_len)
			self._stream.next_out = out
			self._stream.avail_out = chunk_len
			
			status = inflate(self._stream, Z_SYNC_FLUSH)
			if status == Z_NEED_DICT:
				err = inflateSetDictionary(self._stream, HEADER_ZLIB_DICT, len(HEADER_ZLIB_DICT))
				assert err == Z_OK
				continue

			boundary = chunk_len - self._stream.avail_out
			buf.extend(out[:boundary])

			if status == Z_STREAM_END or self._stream.avail_in == 0:
				break
			else:
				assert status == Z_OK

		return bytes(buf)

