# Lockbox

:package: Modern encryption for Rails

- Uses state-of-the-art algorithms
- Works with database fields, files, and strings
- Stores encrypted data in a single field
- Requires you to only manage a single encryption key (with the option to have more)
- Makes migrating existing data and key rotation easy

Encrypted fields and files behave just like unencrypted ones for maximum compatibility with 3rd party libraries and existing code.

Learn [the principles behind it](https://ankane.org/modern-encryption-rails), [how to secure emails with Devise](https://ankane.org/securing-user-emails-lockbox), and [how to secure sensitive data in Rails](https://ankane.org/sensitive-data-rails).

[![Build Status](https://travis-ci.org/ankane/lockbox.svg?branch=master)](https://travis-ci.org/ankane/lockbox)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'lockbox'
```

## Key Generation

Generate an encryption key

```ruby
Lockbox.generate_key
```

Store the key with your other secrets. This is typically Rails credentials or an environment variable ([dotenv](https://github.com/bkeepers/dotenv) is great for this). Be sure to use different keys in development and production. Keys don’t need to be hex-encoded, but it’s often easier to store them this way.

Set the following environment variable with your key (you can use this one in development)

```sh
LOCKBOX_MASTER_KEY=0000000000000000000000000000000000000000000000000000000000000000
```

or create `config/initializers/lockbox.rb` with something like

```ruby
Lockbox.master_key = Rails.application.credentials.lockbox_master_key
```

Then follow the instructions below for the data you want to encrypt.

#### Database Fields

- [Active Record](#active-record)
- [Mongoid](#mongoid)

#### Files

- [Active Storage](#active-storage)
- [CarrierWave](#carrierwave)
- [Shrine](#shrine)
- [Local Files](#local-files)

#### Other

- [Strings](#strings)

## Active Record

Create a migration with:

```ruby
class AddEmailCiphertextToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :email_ciphertext, :text
  end
end
```

Add to your model:

```ruby
class User < ApplicationRecord
  encrypts :email
end
```

You can use `email` just like any other attribute.

```ruby
User.create!(email: "hi@example.org")
```

If you need to query encrypted fields, check out [Blind Index](https://github.com/ankane/blind_index).

#### Types

Fields are strings by default. Specify the type of a field with:

```ruby
class User < ApplicationRecord
  encrypts :born_on, type: :date
  encrypts :signed_at, type: :datetime
  encrypts :opens_at, type: :time
  encrypts :active, type: :boolean
  encrypts :salary, type: :integer
  encrypts :latitude, type: :float
  encrypts :video, type: :binary
  encrypts :properties, type: :json
  encrypts :settings, type: :hash
end
```

**Note:** Use a `text` column for the ciphertext in migrations, regardless of the type

Lockbox automatically works with serialized fields for maximum compatibility with existing code and libraries.

```ruby
class User < ApplicationRecord
  serialize :properties, JSON
  store :settings, accessors: [:color, :homepage]
  attribute :configuration, CustomType.new

  encrypts :properties, :settings, :configuration
end
```

For [StoreModel](https://github.com/DmitryTsepelev/store_model), use:

```ruby
class User < ApplicationRecord
  encrypts :configuration, type: Configuration.to_type

  after_initialize do
    self.configuration ||= {}
  end
end
```

#### Validations

Validations work as expected with the exception of uniqueness. Uniqueness validations require a [blind index](https://github.com/ankane/blind_index).

#### Fixtures

You can use encrypted attributes in fixtures with:

```yml
test_user:
  email_ciphertext: <%= User.generate_email_ciphertext("secret").inspect %>
```

Be sure to include the `inspect` at the end or it won’t be encoded properly in YAML.

#### Migrating Existing Data

Lockbox makes it easy to encrypt an existing column. Add a new column for the ciphertext, then add to your model:

```ruby
class User < ApplicationRecord
  encrypts :email, migrating: true
end
```

Backfill the data in the Rails console:

```ruby
Lockbox.migrate(User)
```

Then update the model to the desired state:

```ruby
class User < ApplicationRecord
  encrypts :email

  # remove this line after dropping email column
  self.ignored_columns = ["email"]
end
```

Finally, drop the unencrypted column.

## Mongoid

Add to your model:

```ruby
class User
  field :email_ciphertext, type: String

  encrypts :email
end
```

You can use `email` just like any other attribute.

```ruby
User.create!(email: "hi@example.org")
```

If you need to query encrypted fields, check out [Blind Index](https://github.com/ankane/blind_index).

## Active Storage

Add to your model:

```ruby
class User < ApplicationRecord
  has_one_attached :license
  encrypts_attached :license
end
```

Works with multiple attachments as well.

```ruby
class User < ApplicationRecord
  has_many_attached :documents
  encrypts_attached :documents
end
```

There are a few limitations to be aware of:

- Metadata like image width and height are not extracted when encrypted
- Direct uploads cannot be encrypted

To serve encrypted files, use a controller action.

```ruby
def license
  user = User.find(params[:id])
  send_data user.license.download, type: user.license.content_type
end
```

## CarrierWave

Add to your uploader:

```ruby
class LicenseUploader < CarrierWave::Uploader::Base
  encrypt
end
```

Encryption is applied to all versions after processing.

You can mount the uploader [as normal](https://github.com/carrierwaveuploader/carrierwave#activerecord). With Active Record, this involves creating a migration:

```ruby
class AddLicenseToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :license, :string
  end
end
```

And updating the model:

```ruby
class User < ApplicationRecord
  mount_uploader :license, LicenseUploader
end
```

To serve encrypted files, use a controller action.

```ruby
def license
  user = User.find(params[:id])
  send_data user.license.read, type: user.license.content_type
end
```

## Shrine

Generate a key

```ruby
key = Lockbox.generate_key
```

Create a lockbox

```ruby
lockbox = Lockbox.new(key: key)
```

Encrypt files before passing them to Shrine

```ruby
LicenseUploader.upload(lockbox.encrypt_io(file), :store)
```

And decrypt them after reading

```ruby
lockbox.decrypt(uploaded_file.read)
```

For models, encrypt with:

```ruby
license = params.require(:user).fetch(:license)
user.license = lockbox.encrypt_io(license)
```

To serve encrypted files, use a controller action.

```ruby
def license
  user = User.find(params[:id])
  send_data box.decrypt(user.license.read), type: user.license.mime_type
end
```

## Local Files

Read the file as a binary string

```ruby
message = File.binread("file.txt")
```

Then follow the instructions for encrypting a string below.

## Strings

Generate a key

```ruby
key = Lockbox.generate_key
```

Create a lockbox

```ruby
lockbox = Lockbox.new(key: key)
```

Encrypt

```ruby
ciphertext = lockbox.encrypt("hello")
```

Decrypt

```ruby
lockbox.decrypt(ciphertext)
```

Use `decrypt_str` get the value as UTF-8

## Key Rotation

To make key rotation easy, you can pass previous versions of keys that can decrypt.

### Active Record

For Active Record, use:

```ruby
class User < ApplicationRecord
  encrypts :email, previous_versions: [{key: previous_key}]
end
```

To rotate, use:

```ruby
user.update!(email: user.email)
```

### Mongoid

For Mongoid, use:

```ruby
class User
  encrypts :email, previous_versions: [{key: previous_key}]
end
```

To rotate, use:

```ruby
user.update!(email: user.email)
```

### Active Storage

For Active Storage use:

```ruby
class User < ApplicationRecord
  encrypts_attached :license, previous_versions: [{key: previous_key}]
end
```

To rotate existing files, use:

```ruby
user.license.rotate_encryption!
```

### CarrierWave

For CarrierWave, use:

```ruby
class LicenseUploader < CarrierWave::Uploader::Base
  encrypt previous_versions: [{key: previous_key}]
end
```

To rotate existing files, use:

```ruby
user.license.rotate_encryption!
```

### Strings

For strings, use:

```ruby
Lockbox.new(key: key, previous_versions: [{key: previous_key}])
```

## Auditing [master, experimental]

It’s a good idea to track user and employee access to sensitive data. Lockbox provides a convenient way to do this with Active Record, but you can use a similar pattern to write audits to any location.

```sh
rails generate lockbox:audits
rails db:migrate
```

Then create an audit wherever a user can view data:

```ruby
class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])

    Lockbox::Audit.create!(
      subject: @user,
      info: "email, dob",
      viewer: current_user,
      ip: request.remote_ip,
      request_id: request.request_id
    )
  end
end
```

Query audits with:

```ruby
Lockbox::Audit.last(100)
```

**Note:** This approach is not intended to be used in the event of a breach or insider attack, as it’s trivial for someone with access to your infrastructure to bypass.

## Algorithms

### AES-GCM

This is the default algorithm. It’s:

- well-studied
- NIST recommended
- an IETF standard
- fast thanks to a [dedicated instruction set](https://en.wikipedia.org/wiki/AES_instruction_set)

**For users who do a lot of encryptions:** You should rotate an individual key after 2 billion encryptions to minimize the chance of a [nonce collision](https://www.cryptologie.net/article/402/is-symmetric-security-solved/), which will expose the key. Each database field and file uploader use a different key (derived from the master key) to extend this window.

### XSalsa20

You can also use XSalsa20, which uses an extended nonce so you don’t have to worry about nonce collisions. First, [install Libsodium](https://github.com/crypto-rb/rbnacl/wiki/Installing-libsodium). For Homebrew, use:

```sh
brew install libsodium
```

And add to your Gemfile:

```ruby
gem 'rbnacl'
```

Then add to your model:


```ruby
class User < ApplicationRecord
  encrypts :email, algorithm: "xsalsa20"
end
```

Make it the default with:

```ruby
Lockbox.default_options = {algorithm: "xsalsa20"}
```

You can also pass an algorithm to `previous_versions` for key rotation.

#### XSalsa20 Deployment

##### Heroku

Heroku [comes with libsodium](https://devcenter.heroku.com/articles/stack-packages) preinstalled.

##### Ubuntu

For Ubuntu 18.04, use:

```sh
sudo apt-get install libsodium23
```

For Ubuntu 16.04, use:

```sh
sudo apt-get install libsodium18
```

##### Travis CI

On Bionic, add to `.travis.yml`:

```yml
addons:
  apt:
    packages:
      - libsodium23
```

On Xenial, add to `.travis.yml`:

```yml
addons:
  apt:
    packages:
      - libsodium18
```

##### CircleCI

Add a step to `.circleci/config.yml`:

```yml
- run:
    name: install Libsodium
    command: |
      sudo apt-get install -y libsodium18
```

## Hybrid Cryptography

[Hybrid cryptography](https://en.wikipedia.org/wiki/Hybrid_cryptosystem) allows servers to encrypt data without being able to decrypt it.

Follow the instructions above for installing Libsodium and including `rbnacl` in your Gemfile.

Generate a key pair with:

```ruby
Lockbox.generate_key_pair
```

Store the keys with your other secrets. Then use:

```ruby
class User < ApplicationRecord
  encrypts :email, algorithm: "hybrid", encryption_key: encryption_key, decryption_key: decryption_key
end
```

Make sure `decryption_key` is `nil` on servers that shouldn’t decrypt.

This uses X25519 for key exchange and XSalsa20 for encryption.

## Key Separation

The master key is used to generate unique keys for each column. This technique comes from [CipherSweet](https://ciphersweet.paragonie.com/internals/key-hierarchy). The table name and column name are both used in this process. If you need to rename a table with encrypted columns, or an encrypted column itself, get the key:

```ruby
Lockbox.attribute_key(table: "users", attribute: "email_ciphertext")
```

And set it directly before renaming:

```ruby
class User < ApplicationRecord
  encrypts :email, key: ENV["USER_EMAIL_ENCRYPTION_KEY"]
end
```

## Key Management

You can use a key management service to manage your keys with [KMS Encrypted](https://github.com/ankane/kms_encrypted).

```ruby
class User < ApplicationRecord
  encrypts :email, key: :kms_key
end
```

For CarrierWave, use:

```ruby
class LicenseUploader < CarrierWave::Uploader::Base
  encrypt key: -> { model.kms_key }
end
```

**Note:** KMS Encrypted’s key rotation does not know to rotate encrypted files, so avoid calling `record.rotate_kms_key!` on models with file uploads for now.

## Data Leakage

While encryption hides the content of a message, an attacker can still get the length of the message (since the length of the ciphertext is the length of the message plus a constant number of bytes).

Let’s say you want to encrypt the status of a candidate’s background check. Valid statuses are `clear`, `consider`, and `fail`. Even with the data encrypted, it’s trivial to map the ciphertext to a status.

```ruby
lockbox = Lockbox.new(key: key)
lockbox.encrypt("fail").bytesize      # 32
lockbox.encrypt("clear").bytesize     # 33
lockbox.encrypt("consider").bytesize  # 36
```

Add padding to conceal the exact length of messages.

```ruby
lockbox = Lockbox.new(key: key, padding: true)
lockbox.encrypt("fail").bytesize      # 44
lockbox.encrypt("clear").bytesize     # 44
lockbox.encrypt("consider").bytesize  # 44
```

The block size for padding is 16 bytes by default. If we have a status larger than 15 bytes, it will have a different length than the others.

```ruby
box.encrypt("length15status!").bytesize   # 44
box.encrypt("length16status!!").bytesize  # 60
```

Change the block size with:

```ruby
Lockbox.new(padding: 32) # bytes
```

## Binary Columns

You can use `binary` columns for the ciphertext instead of `text` columns to save space.

```ruby
class AddEmailCiphertextToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :email_ciphertext, :binary
  end
end
```

You should disable Base64 encoding if you do this.

```ruby
class User < ApplicationRecord
  encrypts :email, encode: false
end
```

or set it globally:

```ruby
Lockbox.default_options = {encode: false}
```

## Compatibility

It’s easy to read encrypted data in another language if needed.

For AES-GCM, the format is:

- nonce (IV) - 12 bytes
- ciphertext - variable length
- authentication tag - 16 bytes

Here are [some examples](docs/Compatibility.md).

For XSalsa20, use the appropriate [Libsodium library](https://libsodium.gitbook.io/doc/bindings_for_other_languages).

## Migrating from Another Library

Lockbox makes it easy to migrate from another library without downtime. The example below uses `attr_encrypted` but the same approach should work for any library.

Let’s suppose your model looks like this:

```ruby
class User < ApplicationRecord
  attr_encrypted :name, key: key
  attr_encrypted :email, key: key
end
```

Create a migration with:

```ruby
class MigrateToLockbox < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :name_ciphertext, :text
    add_column :users, :email_ciphertext, :text
  end
end
```

And add `encrypts` to your model with the `migrating` option:

```ruby
class User < ApplicationRecord
  encrypts :name, :email, migrating: true
end
```

Then run:

```ruby
Lockbox.migrate(User)
```

Once all records are migrated, remove the `migrating` option and the previous model code (the `attr_encrypted` methods in this example).

```ruby
class User < ApplicationRecord
  encrypts :name, :email
end
```

Then remove the previous gem from your Gemfile and drop its columns.

```ruby
class RemovePreviousEncryptedColumns < ActiveRecord::Migration[6.0]
  def change
    remove_column :users, :encrypted_name, :text
    remove_column :users, :encrypted_name_iv, :text
    remove_column :users, :encrypted_email, :text
    remove_column :users, :encrypted_email_iv, :text
  end
end
```

## Upgrading

### 0.2.0

0.2.0 brings a number of improvements. Here are a few to be aware of:

- Added `encrypts` method for database fields
- Added support for XSalsa20
- `attached_encrypted` is deprecated in favor of `encrypts_attached`.

#### Optional

To switch to a master key, generate a key:

```ruby
Lockbox.generate_key
```

And set `ENV["LOCKBOX_MASTER_KEY"]` or `Lockbox.master_key`.

Update your model:

```ruby
class User < ApplicationRecord
  encrypts_attached :license, previous_versions: [{key: key}]
end
```

New uploads will be encrypted with the new key.

You can rotate existing records with:

```ruby
User.unscoped.find_each do |user|
  user.license.rotate_encryption!
end
```

Once that’s complete, update your model:

```ruby
class User < ApplicationRecord
  encrypts_attached :license
end
```

## History

View the [changelog](https://github.com/ankane/lockbox/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/lockbox/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/lockbox/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development and testing:

```sh
git clone https://github.com/ankane/lockbox.git
cd lockbox
bundle install
bundle exec rake test
```
