%w[jing/version erb yaml fileutils time webrick bundler/inline].each { |e| require e }
gemfile { source('https://rubygems.org')
  %w[filewatcher sassc typescript-node uglifier kramdown].each { |e| gem e }
}

module SymbolizeHelper
  extend self
  def symbolize_recursive(hash)
    {}.tap{ |h| hash.each { |key, value| h[key.to_sym] = transform(value) } }
  end
  private
  def transform(thing)
    return symbolize_recursive(thing) if thing.is_a?(Hash)
    return thing.map { |v| transform(v) } if thing.is_a?(Array)
    thing
  end
  refine Hash do
    def deep_symbolize_keys
      SymbolizeHelper.symbolize_recursive(self)
    end
  end
end

module Jing
  using SymbolizeHelper

  class Jing
    attr_accessor :converters, :converter_extensions

    def initialize(opts={})
      @src = File.expand_path(opts[:src] || Dir.pwd)
      @dst = File.expand_path(opts[:dst] || File.join(@src, '_dst'))
      @layouts = opts[:layouts] || '_layouts'
      @partials = opts[:partials] || '_partials'
      @converters = {
        %w[erb] => ->(body, meta, ctx){
          ctx.local_variable_set(:meta, meta)
          ERB.new(body).result(ctx)
        },
        %w[html htm] => ->(body, meta, ctx){
          ctx.local_variable_set(:meta, meta)
          if meta[:layout] && layout = Dir[File.join(@src, @layouts, "#{meta[:layout]}.*")].first
            ctx.local_variable_set(:body, body)
            ERB.new(load_content(layout, meta)[:body]).result(ctx)
          else
            ERB.new(body).result(ctx)
          end
        },
        %w[scss sass css] => ->(body, meta, ctx){
          SassC::Engine.new(body, style: (meta[:style] || :compressed)).render
        },
        %w[ts] =>->(body, meta, ctx){
          TypeScript::Node.compile(body, '--target', (meta[:style] || 'ES5'))
        },
        %w[js] => ->(body, meta, ctx){
          Uglifier.compile(body, harmony: true, compress: false, mangle: false, output: {ascii_only: true})
        },
        %w[md markdown] => ->(body, meta, ctx){
          Kramdown::Document.new(body).to_html
        },
	%w[xml txt] => ->(body, meta, ctx){
          body
        }
      }

      @converter_extensions = @converters.keys.flatten
      File.join(@src, '.meta.yml').tap{|e| @meta = File.exist?(e) ? YAML.load(File.read(e)).deep_symbolize_keys : {}}
    end

    def active_exts(file)
      File.basename(file).split('.').reverse.take_while{|e| @converter_extensions.include?(e)}
    end

    def dstname(file, path=File.dirname(file))
      exts = active_exts(file).reverse
      size = exts.size > 1 ? exts[1..-1].join('.').size+2 : 1
      File.join(path, File.basename(file)[0..-size])
    end

    def load_content(file, meta={})
      body = File.open(file, 'rb'){|f|f.read}
      return {body: body, meta: meta.deep_symbolize_keys} unless @converter_extensions.include?(File.extname(file)[1..-1])
      body.match(/^(?:(---\s*\n.*?\n?)^(?:---\s*$\n?))?(.*)$/m)
      meta.merge!(YAML.load($1).map { |k,v| [k.to_sym,v] }.to_h) if $1
      {body: $2, meta: meta.deep_symbolize_keys}
    end

    def render(file, meta={})
      unless File.file?(file)
        file = Dir[File.join(@src, @partials, "#{file}.*")].first
      else
        meta.merge!(file: file)
      end
      t = Time.now
      content = load_content(file, meta)
      body = content[:body]
      exts = active_exts(file)
      exts.each do |ext|
        converter = @converters[@converters.keys.find { |k| k.include?(ext) }]
        body = converter ? converter.call(body, content[:meta], binding) : body
      end
      puts "#{'%.4fs' % (Time.now-t)}\t#{file[@src.size+1..-1]} >#{exts.join('>')}> #{dstname(file, @dst)[@dst.size+1..-1]} (#{ '%.2fkb' % (body.size/1024.0)})"
      body
    rescue => e
      puts "Error\t#{file[@src.size+1..-1]}\n\t#{e.message}\n#{e.backtrace.map{|x| "\t#{x}"}.join("\n")}"
    end

    def build!(opts={})
      t,s = Time.now, 0
      FileUtils.rm_rf("#{@dst}/.", secure: true)
      Dir.mkdir(@dst) unless File.exist?(@dst)
      Dir[File.join(@src, '**', '*')].each do |file|
        next unless File.file?(file)
        dir = File.dirname(file)[@src.size+1..-1]
        next if dir.to_s.start_with?('_')
        outfile = dstname(file, File.join(*[@dst, dir].compact))
        out = render(file, @meta.merge(layout: dir))
        FileUtils.mkdir_p(File.dirname(outfile))
        File.open(outfile, 'wb'){|f|s+=f.write(out)}
      end
      puts "#{'%.4fs' % (Time.now-t)}, #{'%.2fkb' % (s/1024.0)} total"
    end

    def watch!(opts={})
      @converters[%w[js]] = ->(body, meta, ctx){puts 'skipping uglyfier'; body} unless opts[:full_build]
      build!(opts)
      Filewatcher.new([@src, '**', '*']).watch do |filename, event|
        unless filename.start_with?(@dst)
          puts "\nWATCHED: #{filename}\t#{event}\t#{Time.now}"
          build!(opts)
        end
      end
    end

    def serve!(opts={})
      api_route = opts[:api_route] || '/_J_I_N_G_'
      inter = opts[:interval] || 2000
      script = "<script>((t)=>{setInterval(()=>{fetch('#{api_route}').then(r=>r.json()).then((j)=>{if(Date.parse(j.modified)>t){fetch(document.location.pathname).then((r)=>{if(r.ok)window.location.reload(true)})}})}, #{inter})})(new Date().getTime())</script>"
      srv = WEBrick::HTTPServer.new(Port: opts[:port] || 8000, DocumentRoot: opts[:root] || @dst)

      srv.mount_proc('/') do |rq, rs|
        path = File.join(@dst, rq.path == '/' ? '/index.html' : rq.path)
        raise WEBrick::HTTPStatus::NotFound, "`#{rq.path}' not found." unless File.exist?(path)
        st = File::stat(path)
        rs['etag'] = sprintf("%x-%x-%x", st.ino, st.size, st.mtime.to_i)
        rs['content-type'] = WEBrick::HTTPUtils::mime_type(path, WEBrick::HTTPUtils::DefaultMimeTypes)
        rs['last-modified'] = st.mtime.httpdate
        if rs['content-type'] == 'text/html'
          rs.body = File.open(path, "rb").read.gsub(/(<\/body>)/im){"\n#{script}\n#{$1}"}
          rs['content-length'] = rs.body.size.to_s
        else
          rs['content-length'] = st.size.to_s
          rs.body = File.open(path, "rb")
        end
      end unless opts[:no_auto_reload]

      srv.mount_proc(api_route) do |req, res|
        res['Content-Type'] = 'application/json'
        res.body = {modified: File.stat(@dst).ctime.iso8601}.to_json
      end
      trap('INT'){ srv.stop }
      srv.start
    end

    def create!(opts={})
      abort("usage: #{File.basename($0)} create -name <pathname>") unless opts[:name]
      [@layouts, @partials].each { |e| FileUtils.mkdir_p(File.join(opts[:name], e)) }
      File.write(File.join(opts[:name], '.meta.yml'), "---\ngenerator: jing\nname: #{File.basename(opts[:name])}\n---\n")
    end

    def version!(opts={})
      puts VERSION
    end
  end

  def self.cli!
    cmd = ARGV[0]
    commands = Jing.instance_methods(false).grep(/!$/).map{|e| e[0..-2]}
    abort("usage: #{File.basename($0)} <#{commands.join('|')}>") unless commands.include?(cmd)
    opts = ARGV[1..-1].each_slice(2).reduce({}){|s,(k,v)| s[k.match(/^\-*(.*)$/)[1].to_sym] = v; s}
    jing = Jing.new(opts)
    jing.send(:"#{cmd}!", opts)
  end
end
