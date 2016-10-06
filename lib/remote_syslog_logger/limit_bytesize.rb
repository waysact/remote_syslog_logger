# Adapted from http://stackoverflow.com/a/12536366/2778142
def limit_bytesize(str, size)
  # Change to canonical unicode form (compose any decomposed characters).
  # Works only if you're using active_support
  str = str.mb_chars.compose.to_s if str.respond_to?(:mb_chars)

  # Start with a string of the correct byte size, but
  # with a possibly incomplete char at the end.
  new_str = str.byteslice(0, size)

  # We need to force_encoding from utf-8 to utf-8 so ruby will re-validate
  # (idea from halfelf).
  until new_str[-1].force_encoding(new_str.encoding).valid_encoding?
    # remove the invalid char
    new_str = new_str.slice(0..-2)
  end
  new_str
end
