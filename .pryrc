#coding: utf-8
Pry.config.editor = "vim"

# https://github.com/pry/pry/wiki/FAQ
# Hirbをpryで使う(DBが見やすくなる)
begin
  require 'hirb'
rescue LoadError
end

if defined? Hirb
  Hirb::View.instance_eval do
    def enable_output_method
      @output_method = true
      @old_print = Pry.config.print
      Pry.config.print = proc do |output, value|
        Hirb::View.view_or_page_output(value) || @old_print.call(output, value)
      end
    end

    def disable_output_method
      Pry.config.print = @old_print
      @output_method = nil
    end
  end

  Hirb.enable
end
