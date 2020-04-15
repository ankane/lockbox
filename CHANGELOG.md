- Fixed decryption with Active Storage 6 and `attachment.open`

## 0.3.5 (2020-04-13)

- Added `array` type
- Fixed serialize error with `json` type
- Fixed empty hash with `hash` type

## 0.3.4 (2020-04-05)

- Fixed `migrating: true` with `validate: false`
- Fixed serialization when migrating certain column types

## 0.3.3 (2020-02-16)

- Improved performance of `rotate` for attributes with blind indexes
- Added warning when decrypting previous value fails

## 0.3.2 (2020-02-14)

- Added `encode` option to `Lockbox::Encryptor`
- Added support for `master_key` in `previous_versions`
- Added `Lockbox.rotate` method
- Improved performance of `migrate` method
- Added generator for audits

## 0.3.1 (2019-12-26)

- Fixed encoding for `encrypt_io` and `decrypt_io` in Ruby 2.7
- Fixed deprecation warnings in Ruby 2.7

## 0.3.0 (2019-12-22)

- Added support for custom types
- Added support for virtual attributes
- Made many Mongoid methods consistent with unencrypted columns
- Made `was` and `in_database` methods consistent with unencrypted columns before an update
- Made `restore` methods restore ciphertext
- Fixed virtual attribute being saved with `nil` for Mongoid
- Changed `Lockbox` to module

## 0.2.5 (2019-12-14)

- Made `model.attribute?` consistent with unencrypted columns
- Added `decrypt_str` method
- Improved fixtures for attributes with `type` option

## 0.2.4 (2019-08-16)

- Added support for Mongoid
- Added `encrypt_io` and `decrypt_io` methods
- Made it easier to rotate algorithms with master key
- Fixed error with migrate and default scope
- Fixed encryption with Active Storage 6 and `record.create!`

## 0.2.3 (2019-07-31)

- Added time type
- Added support for rotating padding with same key
- Fixed `OpenSSL::KDF` error on some platforms
- Fixed UTF-8 error

## 0.2.2 (2019-07-24)

- Fixed error with models that have attachments but no encrypted attachments

## 0.2.1 (2019-07-22)

- Added support for types
- Added support for serialized attributes
- Added support for padding
- Added `encode` option for binary columns

## 0.2.0 (2019-07-08)

- Added `encrypts` method for database fields
- Added `encrypts_attached` method
- Added `generate_key` method
- Added support for XSalsa20

## 0.1.1 (2019-02-28)

- Added support for hybrid cryptography
- Added support for database fields

## 0.1.0 (2019-01-02)

- First release
