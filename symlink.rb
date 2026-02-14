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

claude_paths = Dir.glob('_claude/*')

FileUtils.cd ENV['HOME']

dotfiles.each do |dotfile|
  file_in_home = "./#{dotfile}"
  FileUtils.safe_unlink(file_in_home) if FileTest.symlink?(file_in_home)

  FileUtils.ln_s("#{RELATIVE_PATH}/#{dotfile}", "./#{dotfile}", force: true)
  puts "#{current_dir}/#{dotfile}  ->  #{ENV['HOME']}/#{dotfile}"
rescue
  puts "Error occurred. #{dotfile}, file_in_home: #{file_in_home}"
end

claude_paths.each do |path|
  path_in_claude = ".#{path[1..-1]}"
  FileUtils.safe_unlink(path_in_claude) if FileTest.symlink?(path_in_claude)

  FileUtils.ln_s("#{RELATIVE_PATH}/#{path}", "./#{path_in_claude}", force: true)
  puts "#{current_dir}/#{path}  ->  #{ENV['HOME']}/#{path_in_claude}"
rescue
  puts "Error occurred. #{path}, path_in_claude: #{path_in_claude}"
end
