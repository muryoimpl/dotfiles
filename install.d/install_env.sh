# rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
mkdir -p "$(rbenv root)"/plugins
git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
git clone https://github.com/rbenv/rbenv-default-gems.git $(rbenv root)/plugins/rbenv-default-gems
echo "bundler" > $(rbenv root)/default-gems
git clone https://github.com/rkh/rbenv-update.git "$(rbenv root)/plugins/rbenv-update"

# nodenv
git clone https://github.com/nodenv/nodenv.git ~/.nodenv
mkdir -p "$(nodenv root)"/plugins
git clone https://github.com/nodenv/nodenv-update.git "$(nodenv root)"/plugins/nodenv-update
git clone https://github.com/nodenv/node-build.git $(nodenv root)/plugins/node-build

# goenv
git clone https://github.com/syndbg/goenv.git ~/.goenv
cd goenv/plugins/go-build
./install.sh
git://github.com/juxtaposedwords/goenv-update.git ~/.goenv/plugins/goenv-update

# exenv
git clone git://github.com/mururu/exenv.git ~/.exenv
