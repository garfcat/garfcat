set -x
hugo 
rm -rf docs && cp -rf public docs
cp -rf static docs/
