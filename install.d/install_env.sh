# rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
mkdir -p ~/.rbenv/plugins
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
git clone https://github.com/rbenv/rbenv-default-gems.git ~/.rbenv/plugins/rbenv-default-gems
echo "bundler" > ~/.rbenv/plugins/default-gems
git clone https://github.com/rkh/rbenv-update.git ~/.rbenv/plugins/rbenv-update

# nodenv
git clone https://github.com/nodenv/nodenv.git ~/.nodenv
mkdir -p ~/.nodenv/plugins
git clone https://github.com/nodenv/nodenv-update.git ~/.nodenv/plugins/nodenv-update
git clone https://github.com/nodenv/node-build.git ~/.nodenv/plugins/node-build
