# Usage: ruby tools/fast_desc.rb <config.rb> <cache.marshal> <out.tsv> [path-regex]
#
# Runs the description rules over the pages cached by tools/build_cache.rb,
# without rendering Markdown, and writes one row per page:
# path <TAB> 200 <TAB> description <TAB> title <TAB> source. Write the output
# outside the repository, for example to the session scratchpad.
require 'gollum/app'
config, cache, out, filter = ARGV
Precious::App.set(:wiki_options, {})
load config
StubPage = Struct.new(:url_path, :url_path_title, :format, :metadata)
data = Marshal.load(File.binread(cache))
data = data.select { |d| d[0].match?(Regexp.new(filter)) } if filter
File.open(out, 'w:UTF-8') do |f|
  data.each do |p, url_path, url_title, html, meta|
    v = Precious::Views::Page.allocate
    v.instance_variable_set(:@page, StubPage.new(url_path, url_title, :markdown, meta || {}))
    v.instance_variable_set(:@content, html.to_s.dup.force_encoding('UTF-8'))
    v.instance_variable_set(:@h1_title, true)
    d = begin
      v.description
    rescue => e
      "ERROR #{e.class}: #{e.message} #{e.backtrace.first}"
    end
    src = v.instance_variable_get(:@seo_describer)&.source
    f.puts [p, 200, d, v.title, src].join("\t")
  end
end
puts "done #{data.length}"
