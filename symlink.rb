require 'fileutils'

IGNORE_FILES = %w(. .. .DS_Store .git .config install.d)

current_dir = Dir.pwd

dotfiles = Dir.glob('.*').reject {|f| IGNORE_FILES.include?(f) }

dotfiles.each do |dotfile|
  # FileUtils.ln_s("#{current_dir}/#{dotfile}", "#{ENV['HOME']}/#{dotfile}", force: true)
  puts "#{current_dir}/#{dotfile}  ->  #{ENV['HOME']}/#{dotfile}"
end
