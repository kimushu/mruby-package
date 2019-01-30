#!/usr/bin/env ruby

PACKAGE_VERSION = "1.0.7"
MRUBY_VERSIONS = Dir.glob("../mruby/mruby-*").sort.map {|path| [path.sub(/.*-/, ""), path]}.to_h
MRUBY_GEMS = {}

module MRuby
    def self.each_target
    end
    class Build
        attr_accessor :bins, :libmruby
        def initialize(mruby_dir)
            @mruby_dir = mruby_dir
            @bins = []
            @libmruby = []
        end
        def root
            @mruby_dir
        end
        def libmruby_core_static
        end
        class Toolchain
            def initialize
                @include_paths = []
                @library_paths = []
                @libraries = []
                @defines = []
            end
            attr_accessor :include_paths, :library_paths, :libraries, :defines
            def search_header_path(path)
                false
            end
        end
        def cc
            @cc ||= Toolchain.new
        end
        def linker
            @linker ||= Toolchain.new
        end
        def build_dir
        end
        class Extensions
            def executable
            end
            def object
            end
        end
        def exts
            @exts ||= Extensions.new
        end
        def file(path)
            path
        end
        def objfile(path)
            path
        end
        def libfile(path)
            path
        end
        def cxx_exception_enabled?
            false
        end
        class Gems
            def generate_gem_table(build)
            end
            def each(&block)
            end
        end
        def gems
            @@gems ||= Gems.new
        end
    end
    class CrossBuild < Build
    end
    module Gem
        class Specification < Build
            def self.scan(mruby_ver, mruby_dir)
                @@mruby_ver = mruby_ver
                @@mruby_dir = mruby_dir
                @@gems = []
                Dir.glob("#{@@mruby_dir}/mrbgems/*/mrbgem.rake").each do |path|
                    load(path)
                end
                @@gems.each do |gem|
                    gem.setup
                end
                return @@gems.size
            end
            def initialize(name, &block)
                super(@@mruby_dir)
                @name = name
                @initializer = block
                @license = nil
                @authors = nil
                @summary = nil
                @version = nil
                @bins = []
                @test_rbfiles = []
                @@gems << self
            end
            attr_accessor :license, :authors, :summary, :version, :bins, :test_rbfiles
            def setup
                unless @name == "mruby-test"
                    MRUBY_GEMS[@name] ||= {}
                    MRUBY_GEMS[@name][@@mruby_ver] = {:dependencies => []}
                    instance_eval &@initializer
                    MRUBY_GEMS[@name][:summary] = @summary
                end
            end
            def build
                self
            end
            def dir
                "#{@@mruby_dir}/#{@name}"
            end
            def author=(author)
                @authors = [author]
            end
            def add_test_dependency(name, *options)
            end
            def add_dependency(name, *options)
                MRUBY_GEMS[@name][@@mruby_ver][:dependencies] << name
            end
        end
    end
end

puts "=" * 64
puts "Scanning mruby versions\n  => #{MRUBY_VERSIONS.keys.inspect}"

MRUBY_VERSIONS.each_pair do |ver, dir|
    unless File.exists?("#{dir}/build_config.rb")
        abort "Error: Files for mruby #{ver} not found.\n" +
            "Hint: Did you execute 'git submodule update --init' after cloning this repository?"
    end

    puts "Fetching mrbgem information for mruby #{ver} ..."
    n = MRuby::Gem::Specification.scan(ver, dir)
    puts "  => #{n} gems found"
end

f = open("kimu_shu.Runtime-mruby.pdsc", "w")
f.puts <<EOD
<?xml version="1.0" encoding="utf-8"?>

<package schemaVersion="1.4" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="PACK.xsd">
  <vendor>kimu_shu</vendor>
  <name>Runtime-mruby</name>
  <description>Unofficial software package for mruby</description>
  <url></url>
  <supportContact>kimura.shuta@gmail.com</supportContact>
  <!--
  <license>
  </license>
  -->

  <releases>
    <release version="#{PACKAGE_VERSION}">
      Initial software pack release
    </release>
  </releases>

  <keywords>
    <keyword>Ruby</keyword>
    <keyword>mruby</keyword>
    <keyword>Runtime</keyword>
    <keyword>Scripting Language</keyword>
  </keywords>

  <conditions>
    <condition id="Cortex-M">
      <description>Cortex-M based device</description>
      <accept Dcore="Cortex-M3"/>
      <accept Dcore="Cortex-M4"/>
      <accept Dcore="Cortex-M7"/>
    </condition>
    <condition id="ARMCC">
      <description>ARMCC compiler</description>
      <require Tcompiler="ARMCC"/>
    </condition>
    <condition id="IAR">
      <description>IAR compiler</description>
      <require Tcompiler="IAR"/>
    </condition>
    <condition id="GCC">
      <description>GCC compiler</description>
      <require Tcompiler="GCC"/>
    </condition>
    <condition id="Cortex-M ARMCC">
      <description>Cortex-M based device / ARMCC compiler</description>
      <require condition="Cortex-M"/>
      <require condition="ARMCC"/>
    </condition>
    <condition id="Cortex-M IAR">
      <description>Cortex-M based device / IAR compiler</description>
      <require condition="Cortex-M"/>
      <require condition="IAR"/>
    </condition>
    <condition id="Cortex-M GCC">
      <description>Cortex-M based device / GCC compiler</description>
      <require condition="Cortex-M"/>
      <require condition="GCC"/>
    </condition>
    <condition id="Dummy Dependencies">
      <description>Dummy Dependencies</description>
    </condition>
    <condition id="mruby-core Dependencies">
      <description>mruby Dependencies</description>
      <require Cgroup="mruby-core" Cclass="mruby"/>
    </condition>
EOD
MRUBY_VERSIONS.each_pair do |ver, dir|
    f.puts <<EOD
    <condition id="mruby #{ver} Dependencies">
      <description>mruby #{ver} Dependencies</description>
      <require Cgroup="mruby-core" Cclass="mruby" Cvariant="#{ver}"/>
    </condition>
EOD
end
MRUBY_GEMS.each_pair do |name, vers|
    f.puts <<EOD
    <condition id="#{name} Dependencies">
      <description>#{name} Dependencies</description>
EOD
    required = {}
    allvers = []
    MRUBY_VERSIONS.each_key do |ver|
        i = vers[ver]
        next unless i
        allvers << ver
        f.puts <<EOD
      <accept condition="mruby #{ver} Dependencies"/>
EOD
        i[:dependencies].each do |dep|
            required[dep] ||= []
            required[dep] << ver
        end
    end
    required.each_pair do |dep, vers|
        if (vers == allvers)
            f.puts <<EOD
      <require condition="#{dep} Dependencies"/>
EOD
        else
            abort "not supported #{name} => #{dep}"
        end
    end
    f.puts <<EOD
    </condition>
EOD
end
f.puts <<EOD
  </conditions>

  <!-- optional taxonomy section for defining new component Class and Group names -->
  <taxonomy>
    <description Cclass="mruby">mruby</description>
  </taxonomy>

  <!-- component section (optional for all Software Packs)-->
  <components>
    <bundle Cclass="mruby" Cbundle="mruby" Cversion="#{PACKAGE_VERSION}">
      <description>Lightweight implementation of the Ruby language complying with part of the ISO standard</description>
      <doc/>
EOD
MRUBY_VERSIONS.each_pair do |ver, dir|
    f.puts <<EOD
      <component Cgroup="mruby-core" Cvariant="#{ver}" condition="Dummy Dependencies">
        <description>Core of mruby</description>
        <files>
          <file name="Middlewares/Third_Party/mruby-#{ver}/include/" category="include"/>
EOD
    Dir.chdir(dir) do
        Dir.glob("include/**/*.h").each do |h|
            f.puts <<EOD
          <file name="Middlewares/Third_Party/mruby-#{ver}/#{h}" category="header"/>
EOD
        end
    end
    f.puts <<EOD
        </files>
      </component>
EOD
end
MRUBY_GEMS.each_pair do |name, vers|
    f.puts <<EOD
      <component Cgroup="#{name}" condition="#{name} Dependencies">
        <description>#{vers[:summary]}</description>
        <files>
        </files>
      </component>
EOD
#         <file name="Middlewares/Third_Party/mruby-1.4.1/mrbgems/mruby-array-ext/mrbgem.rake" category="other" condition="mruby 1.4.1 Dependencies"/>
#         <file name="Middlewares/Third_Party/mruby-2.0.0/mrbgems/mruby-array-ext/mrbgem.rake" category="other" condition="mruby 2.0.0 Dependencies"/>
end
f.puts <<EOD
    </bundle>
  </components>

  <!-- examples section (optional for all Software Packs)-->
  <!--
  <examples>
  </examples>
  -->

</package>
EOD
f.close
