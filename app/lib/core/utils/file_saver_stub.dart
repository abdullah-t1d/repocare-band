/// Outside the browser there is no download; callers check support first.
void saveTextFile(String fileName, String content, {String mimeType = 'text/csv'}) =>
    throw UnsupportedError('File download is only available on the web');
