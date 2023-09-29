require 'irb'
require 'irb/completion'
require 'rubygems'

def rails_env
  return nil unless defined?(Rails)

  env_name = ENV['RAILS_ENV']
  if env_name == 'production'
    "\e[41;97;1m #{env_name} \e[0m "
  else
    "\e[42;97;1m #{env_name} \e[0m "
  end
end

def ihelp
  show_cmds
end

def examples
  puts <<HELP
  fg(n)             > fg 1
  kill(n)           > kill 1
  source <path>     > source "./test.rb"
  help <names>      > help Array#match
  show_source       > show_source Set#merge  # alias: $
  whereami          > whereami               # alias: @
HELP
end

IRB.conf[:HISTORY_FILE] = "#{ENV['HOME']}/.irb_history"
IRB.conf[:PROMPT][:MY] = {
  PROMPT_I: "%N(%m):%03n:%i:#{rails_env}> ",
  PROMPT_N: "%N(%m):%03n:%i:#{rails_env}> ",
  PROMPT_S: "%N(%m):%03n:%i:#{rails_env}:%l: ",
  PROMPT_C: "%N(%m):%03n:%i:#{rails_env}* ",
  RETURN: ":  %s\n",
}
IRB.conf[:PROMPT_MODE] = :MY

IRB.conf[:USE_AUTOCOMPLETE] = false
