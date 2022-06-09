require_relative "lib/lockbox/version"

Gem::Specification.new do |spec|
  spec.name          = "lockbox"
  spec.version       = Lockbox::VERSION
  spec.summary       = "Modern encryption for Ruby and Rails"
  spec.homepage      = "https://github.com/ankane/lockbox"
  spec.license       = "MIT"

  spec.author        = "Andrew Kane"
  spec.email         = "andrew@ankane.org"

  spec.files         = Dir["*.{md,txt}", "{lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 2.6"
end
