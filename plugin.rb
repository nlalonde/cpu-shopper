# frozen_string_literal: true

# name: cpu-shopper
# transpile_js: true
# about: Shop for my new CPU for me.
# version: 0.1
# authors: Neil Lalonde
# url: https://github.com/nlalonde/cpu-shopper

enabled_site_setting :neil_cpu_shopper

after_initialize do
  [
    "../app/jobs/scheduled/canada_computers_checker.rb",
  ].each { |path| load File.expand_path(path, __FILE__) }
end
