
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "lockbox/version"

Gem::Specification.new do |spec|
  spec.name          = "lockbox"
  spec.version       = Lockbox::VERSION
  spec.summary       = "File encryption for Ruby and Rails. Supports Active Storage and CarrierWave."
  spec.homepage      = "https://github.com/ankane/lockbox"
  spec.license       = "MIT"

  spec.author        = "Andrew Kane"
  spec.email         = "andrew@chartkick.com"

  spec.files         = Dir["*.{md,txt}", "{lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 2.2"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "carrierwave"
  spec.add_development_dependency "activestorage"
  spec.add_development_dependency "activejob"
  spec.add_development_dependency "combustion"
  spec.add_development_dependency "sqlite3", "~> 1.3.0"
  spec.add_development_dependency "rbnacl"
  spec.add_development_dependency "attr_encrypted"
end
