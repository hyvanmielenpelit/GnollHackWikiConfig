# Usage: ruby tools/dump_descriptions.rb <config.rb> <wiki> <out.tsv> [page.md ...]
#
# Renders wiki pages through Precious::App in-process, with config.rb loaded
# and the wiki's own .gollum/templates, and writes one row per page:
# path <TAB> status <TAB> description <TAB> title. Beside it, writes
# <out>_sitemap.xml from GET /sitemap.xml. Write the outputs outside the
# repository, for example to the session scratchpad.
require 'erb'
require 'cgi'
require 'rack/mock'
require 'gollum/app'

config, wiki, out, *only = ARGV
Precious::App.set(:environment, :production)
Precious::App.set(:gollum_path, wiki)
Precious::App.set(:wiki_options, {})
load config
Precious::App.set(:wiki_options, Precious::App.settings.wiki_options.merge(template_dir: File.join(wiki, '.gollum/templates')))

pages = only.empty? ? Dir.glob('**/*.md', base: wiki).reject { |p| p.start_with?('uploads/') }.sort : only
req = Rack::MockRequest.new(Precious::App)
File.binwrite(out.sub(/\.tsv\z/, '') + '_sitemap.xml', req.get('/sitemap.xml').body)
# A config with clean page URLs serves each page at its canonical path; an
# older config, and a page outside the index, at its extensionless file path.
index = defined?(GnollHackPageIndexCache) ? GnollHackPageIndexCache.current : nil
File.open(out, 'w:UTF-8') do |f|
  pages.each do |p|
    url = index&.canonical_path(p) || '/' + p.sub(/\.md\z/, '').split('/').map { |s| ERB::Util.url_encode(s) }.join('/')
    res = req.get(url)
    body = res.body.to_s.dup.force_encoding('UTF-8')
    desc = body[/<meta name="description" content="([^"]*)"/, 1]
    title = body[/<title>([^<]*)<\/title>/, 1]
    f.puts [p, res.status, desc ? CGI.unescapeHTML(desc) : '(none)', title ? CGI.unescapeHTML(title) : ''].join("\t")
  end
end
puts "done #{pages.length}"
