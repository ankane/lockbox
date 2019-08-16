## 0.2.4 [unreleased]

- Added support for Mongoid
- Added `encrypt_io` and `decrypt_io` methods
- Made it easier to rotate algorithms with master key
- Fixed error with migrate and default scope

## 0.2.3

- Added time type
- Added support for rotating padding with same key
- Fixed `OpenSSL::KDF` error on some platforms
- Fixed UTF-8 error

## 0.2.2

- Fixed error with models that have attachments but no encrypted attachments

## 0.2.1

- Added support for types
- Added support for serialized attributes
- Added support for padding
- Added `encode` option for binary columns

## 0.2.0

- Added `encrypts` method for database fields
- Added `encrypts_attached` method
- Added `generate_key` method
- Added support for XSalsa20

## 0.1.1

- Added support for hybrid cryptography
- Added support for database fields

## 0.1.0

- First release
