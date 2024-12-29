## 2.0.1 (2024-12-29)

- Added support for Ruby 3.4

## 2.0.0 (2024-10-26)

- Improved `attributes`, `attribute_names`, and `has_attribute?` when ciphertext attributes not loaded
- Removed deprecated `lockbox_encrypts` (use `has_encrypted` instead)
- Dropped support for Active Record < 7 and Ruby < 3.1
- Dropped support for Mongoid < 8

## 1.4.1 (2024-09-09)

- Fixed error message for previews for Active Storage 7.1.4

## 1.4.0 (2024-08-09)

- Added support for Active Record 7.2
- Added support for Mongoid 9
- Fixed error when `decryption_key` option is a proc or symbol and returns `nil`

## 1.3.3 (2024-02-07)

- Added warning for encrypting store attributes

## 1.3.2 (2024-01-10)

- Fixed issue with serialized attributes

## 1.3.1 (2024-01-06)

- Fixed error with `array` and `hash` types and no default column serializer with Rails 7.1
- Fixed Action Text deserialization with Rails 7.1

## 1.3.0 (2023-07-02)

- Added support for CarrierWave 3

## 1.2.0 (2023-03-20)

- Made it easier to rotate master key
- Added `associated_data` option for database fields and files
- Added `decimal` type
- Added `encode_attributes` option
- Fixed deprecation warnings with Rails 7.1

## 1.1.2 (2023-02-01)

- Fixed error when migrating to `array`, `hash`, and `json` types

## 1.1.1 (2022-12-08)

- Fixed error when `StringIO` not loaded

## 1.1.0 (2022-10-09)

- Added support for `insert`, `insert_all`, `insert_all!`, `upsert`, and `upsert_all`

## 1.0.0 (2022-06-11)

- Deprecated `encrypts` in favor of `has_encrypted` to avoid conflicting with Active Record encryption
- Deprecated `lockbox_encrypts` in favor of `has_encrypted`
- Fixed error with `pluck`
- Restored warning for attributes with `default` option
- Dropped support for Active Record < 5.2 and Ruby < 2.6

## 0.6.8 (2022-01-25)

- Fixed issue with `encrypts` loading model schema early
- Removed warning for attributes with `default` option

## 0.6.7 (2022-01-25)

- Added warning for attributes with `default` option
- Removed warning for Active Record 5.0 (still supported)

## 0.6.6 (2021-09-27)

- Fixed `attribute?` method for `boolean` and `integer` types

## 0.6.5 (2021-07-07)

- Fixed issue with `pluck` extension not loading in some cases

## 0.6.4 (2021-04-05)

- Fixed in place changes in callbacks
- Fixed `[]` method for encrypted attributes

## 0.6.3 (2021-03-30)

- Fixed empty arrays and hashes
- Fixed content type for CarrierWave 2.2.1

## 0.6.2 (2021-02-08)

- Added `inet` type
- Fixed error when `lockbox` key in Rails credentials has a string value
- Fixed deprecation warning with Active Record 6.1

## 0.6.1 (2020-12-03)

- Added integration with Rails credentials
- Added warning for unsupported versions of Active Record
- Fixed in place changes for Active Record 6.1
- Fixed error with `content_type` method for CarrierWave < 2

## 0.6.0 (2020-12-03)

- Added `encrypted` flag to Active Storage metadata
- Added encrypted columns to `filter_attributes`
- Improved `inspect` method

## 0.5.0 (2020-11-22)

- Improved error messages for hybrid cryptography
- Changed warning to error when no attributes specified
- Fixed issue with `pluck` when migrating
- Fixed error with `key_table` and `key_attribute` options with `previous_versions`

## 0.4.9 (2020-10-01)

- Added `key_table` and `key_attribute` options to `previous_versions`
- Added `encrypted_attribute` option
- Added support for encrypting empty string
- Improved `inspect` for models with encrypted attributes

## 0.4.8 (2020-08-30)

- Added `key_table` and `key_attribute` options
- Added warning when no attributes specified
- Fixed error when Active Support partially loaded

## 0.4.7 (2020-08-18)

- Added `lockbox_options` method to encrypted CarrierWave uploaders
- Improved attribute loading when no decryption key specified

## 0.4.6 (2020-07-02)

- Added support for `update_column` and `update_columns`

## 0.4.5 (2020-06-26)

- Improved error message for non-string values
- Fixed error with migrating Action Text
- Fixed error with migrating serialized attributes

## 0.4.4 (2020-06-23)

- Added support for `pluck`

## 0.4.3 (2020-05-26)

- Improved error message for bad key length
- Fixed missing attribute error

## 0.4.2 (2020-05-11)

- Added experimental support for migrating Active Storage files
- Fixed `metadata` support for Active Storage

## 0.4.1 (2020-05-08)

- Added support for Action Text
- Added warning if unencrypted column exists and not migrating

## 0.4.0 (2020-05-03)

- Load encrypted attributes when `attributes` called
- Added support for migrating and rotating relations
- Removed deprecated `attached_encrypted` method
- Removed legacy `attr_encrypted` encryptor

## 0.3.7 (2020-04-20)

- Added Active Support notifications for Active Storage and Carrierwave

## 0.3.6 (2020-04-19)

- Fixed content type detection for Active Storage and CarrierWave
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
