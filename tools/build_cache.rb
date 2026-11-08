# Usage: ruby tools/build_cache.rb <wiki> <out.marshal>
#
# Renders every wiki page once with gollum-lib and stores
# [path, url_path, url_path_title, formatted_data, metadata] per page, for
# tools/fast_desc.rb. The wiki options match the rendering options config.rb
# sets (h1_title, case_insensitive_tag_lookup, math). Write the cache outside
# the repository, for example to the session scratchpad.
require 'gollum-lib'
wiki_path, out = ARGV
wiki = Gollum::Wiki.new(wiki_path, h1_title: true, case_insensitive_tag_lookup: true, math: :katex)
pages = Dir.glob('**/*.md', base: wiki_path).reject { |p| p.start_with?('uploads/') }.sort
data = pages.map do |p|
  page = wiki.page(p.sub(/\.md\z/, ''))
  next [p, nil, nil, nil, nil] unless page
  html = page.formatted_data
  [p, page.url_path, page.url_path_title, html, page.metadata]
end
File.binwrite(out, Marshal.dump(data))
puts "cached #{data.length}, missing #{data.count { |d| d[1].nil? }}"
