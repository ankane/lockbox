require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false # for shrine (fixed but not released)
end

task default: :test

task :benchmark do
  require "benchmark/ips"
  require "lockbox"
  require "rbnacl"

  key = Lockbox.generate_key
  value = "secret" * 5

  aes_gcm = Lockbox.new(key: key, algorithm: "aes-gcm")
  xsalsa20 = Lockbox.new(key: key, algorithm: "xsalsa20")

  Benchmark.ips do |x|
    x.report("aes-gcm") { aes_gcm.decrypt(aes_gcm.encrypt(value)) }
    x.report("xsalsa20") { xsalsa20.decrypt(xsalsa20.encrypt(value)) }
  end
end
