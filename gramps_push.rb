#!/usr/bin/env ruby

require 'fileutils'

module OS
  def OS.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  def OS.mac?
    (/darwin/ =~ RUBY_PLATFORM) != nil
  end

  def OS.unix?
    !OS.windows?
  end

  def OS.linux?
    OS.unix? and not OS.mac?
  end
end

tree = ARGV[0]

%x{gramps -O "#{tree}" -e "#{tree}.gramps.gz -f gramps"}
%x{gunzip "#{tree}.gramps.gz"}
%x{scp "#{tree}.gramps" gramps@pi:archive/}
