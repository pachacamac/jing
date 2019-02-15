require "jing/version"

module Jing
  class Jing
    attr_accessor :converters, :converter_extensions

    def initialize(opts={})
      @src = File.expand_path(opts[:src] || Dir.pwd)
      @dst = File.expand_path(opts[:dst] || File.join(@src, '_dst'))
      @converters = (opts[:converter_addons] || []) + [
        {extensions: %w[erb], handler: Proc.new { |body, meta, ctx|
          ERB.new(body).result(OpenStruct.new(meta: meta).instance_eval { ctx })
        }},
        {extensions: %w[html htm], handler: Proc.new { |body, meta, ctx|
          if meta[:layout] && layout = Dir[File.join(@src, '_layouts', "#{meta[:layout]}.*")].first
            content = load_content(layout, meta)
            ERB.new(content[:body]).result(OpenStruct.new(meta: meta, body: body).instance_eval { ctx })
          else
            ERB.new(body).result(OpenStruct.new(meta: meta).instance_eval { ctx })
          end
        }},
        {extensions: %w[scss sass], handler: ->(body, meta, ctx){
          load_gem 'sassc'
          SassC::Engine.new(body, style: (meta[:style] || :compressed)).render
        }},
        {extensions: %w[ts], handler: ->(body, meta, ctx){
          load_gem 'typescript-node'
          TypeScript::Node.compile(body, '--target', (meta[:style] || 'ES5'))
        }},
        {extensions: %w[js], handler: ->(body, meta, ctx){
          load_gem 'uglifier'
          Uglifier.compile(body, harmony: true)
        }},
        {extensions: %w[md markdown], handler: ->(body, meta, ctx){
          load_gem 'kramdown'
          Kramdown::Document.new(body).to_html
        }},
      ]

      @converter_extensions = @converters.map { |e| e[:extensions] }.flatten
      main_meta_file = File.join(@src, '.meta.yml')
      @meta = YAML.load(File.read(main_meta_file)).map { |k,v| [k.to_sym,v] }.to_h if File.exist?(main_meta_file)
    end

    def load_gem(name, opts={})
      gemfile { source(opts.delete(:source)||'https://rubygems.org'); gem(name, opts) }
    end

    def dstname(file, path=File.dirname(file))
      File.join(path, File.basename(file).split('.', 3)[0..1].join('.'))
    end

    def load_content(file, meta={})
      body = File.open(file, 'rb').read
      return {body: body, meta: meta} unless @converter_extensions.include?(File.extname(file)[1..-1])
      body.match(/^(?:(---\s*\n.*?\n?)^(?:---\s*$\n?))?(.*)$/m)
      meta.merge!(YAML.load($1).map { |k,v| [k.to_sym,v] }.to_h) if $1
      {body: $2, meta: meta}
    end

    def render(file, meta={})
      if !File.file?(file)
        file = Dir[File.join(@src, '_partials', "#{file}.*")].first
      else
        meta.merge!(file: file)
      end
      t = Time.now
      content = load_content(file, meta)
      body = content[:body]
      File.basename(file).split('.')[1..-1].reverse.each do |ext|
        converter = @converters.find { |c| c[:extensions].include?(ext) }
        body = converter ? converter[:handler].call(body, content[:meta], binding) : body
      end
      puts "#{'%.4fs' % (Time.now-t)}\t#{file[@src.size+1..-1]} => #{dstname(file, @dst)[@dst.size+1..-1]} (#{(body.size/1024.0).round(2)}kb)"
      body
    rescue => e
      puts "Error\t#{file[@src.size+1..-1]}\n\t#{e.message}\n#{e.backtrace.map{|x| "\t#{x}"}.join("\n")}"
    end

    def build!
      t = Time.now
      FileUtils.rm_r(@dst) if File.exist?(@dst)
      Dir.mkdir(@dst)
      Dir[File.join(@src, '**', '*')].each do |file|
        next unless File.file?(file)
        dir = File.dirname(file)[@src.size+1..-1]
        next if dir.to_s.start_with?('_')
        outfile = dstname(file, File.join(*[@dst, dir].compact))
        out = render(file, @meta.merge(layout: dir))
        FileUtils.mkdir_p(File.dirname(outfile))
        File.open(outfile, 'wb').write(out)
      end
      puts "#{'%.4fs' % (Time.now-t)} total"
    end

    def watch!
      @converter_extensions.delete('js')
      build!
      load_gem('filewatcher')
      Filewatcher.new([@src, '**', '*']).watch do |filename, event|
        puts "WATCHED #{filename}\t#{event}"
        build!
      end
    end

    def serve!
      WEBrick::HTTPServer.new(Port: 8000, DocumentRoot: @dst).start
    end

    def create!
      abort("usage: #{File.basename($0)} create <name/path>") unless ARGV[1]
      %w[_layouts _partials].each { |e| FileUtils.mkdir_p(File.join(ARGV[1], e)) }
      File.write(File.join(ARGV[1], '.meta.yml'), "---\ngenerator: jing\nname: #{File.basename(ARGV[1])}\n---\n")
    end
  end

  def self.cli!
    cmd = ARGV[0]
    commands = Jing.instance_methods(false).grep(/!$/).map{|e| e[0..-2]}
    abort("usage: #{File.basename($0)} <#{commands.join('|')}>") unless commands.include?(cmd)
    jing = Jing.new()
    jing.send(:"#{cmd}!")
  end
end
