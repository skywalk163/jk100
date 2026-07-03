test "sha256_empty_string" {
  let input = ""
  let expected = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  let result = bytes_sha256(input.to_bytes())
  assert_eq(result, expected)
}

test "sha256_abc" {
  let input = "abc"
  let expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  let result = bytes_sha256(input.to_bytes())
  assert_eq(result, expected)
}