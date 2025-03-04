#!/usr/bin/env sh
export GOPROXY="https://proxy.golang.org,direct" GOAMD64='v3'
export output="final"
export py_script=".github/sing-box.py"

function exp() {
	python ${py_script} ${output}.json templates/template-${1}.json release/Sing-Box/${1}-lite.json
	python ${py_script} ${output}.json templates/template-${1}-sfw.json release/Sing-Box/${1}-sfw-lite.json
	python ${py_script} ${output}.json templates/template-${1}-notun.json release/Sing-Box/${1}-lite-notun.json
	python ${py_script} ${output}.json templates/template-${1}-sfw-notun.json release/Sing-Box/${1}-sfw-lite-notun.json
}

git clone https://github.com/SagerNet/serenity
cd serenity && make install 2> /dev/null && cd ..
serenity -c ".github/serenity.json" run &

git clone https://github.com/SagerNet/sing-box
cd sing-box && git checkout main-next && make install 2> /dev/null && cd ..

curl -fsSL http://127.0.0.1:8080/${output} | jq -Sc > ${output}.json || echo "CURL FAILED!"

#quick-fix
sed -i s/\;mux\=true//g ${output}.json
sed -i s/mux\=true\;//g ${output}.json

exp cn && echo "CN files exported!"
exp ir && echo "IR files exported!"
exp ru && echo "RU files exported!"

for i in release/Sing-Box/*.json; do sing-box check -c "$i" && echo "'$i' is OK!"; done
echo "SUCCESS!"

## Updating direct rule-set
sing-box rule-set format -w direct.json && sing-box rule-set compile direct.json && echo "Direct rule-set updated!"
sing-box rule-set format -w block.json && sing-box rule-set compile block.json && echo "Block rule-set updated!"
