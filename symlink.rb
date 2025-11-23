require 'fileutils'
require 'rbconfig'

IGNORE_FILES = %w(. .. .DS_Store .git .config install.d .zshenv .xprofile .zprofile)
RELATIVE_PATH = './ghq/github.com/muryoimpl/dotfiles'

ignored =
  case RbConfig::CONFIG['host_os']
  when /darwin/
    IGNORE_FILES + %w(.zshenv .zprofile .xprofile)
  when /linux/
    IGNORE_FILES
  else
  end

current_dir = Dir.pwd
dotfiles = Dir.glob('.*').reject {|f| ignored.include?(f) }
dotfiles << 'local'

FileUtils.cd ENV['HOME']

dotfiles.each do |dotfile|
  file_in_home = "./#{dotfile}"
  FileUtils.safe_unlink(file_in_home) if FileTest.symlink?(file_in_home)

  FileUtils.ln_s("#{RELATIVE_PATH}/#{dotfile}", "./#{dotfile}", force: true)
  puts "#{current_dir}/#{dotfile}  ->  #{ENV['HOME']}/#{dotfile}"
rescue
  puts "Error occurred. #{dotfile}, file_in_home: #{file_in_home}"
end
