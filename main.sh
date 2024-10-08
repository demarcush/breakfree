#!/usr/bin/env sh
export GOPROXY="https://proxy.golang.org,direct" GOAMD64='v3'
export SRV=final

function exp() {
	python main.py ${SRV}.json templates/template-${1}.json release/Sing-Box/${1}-lite.json
	python main.py ${SRV}.json templates/template-${1}-sfw.json release/Sing-Box/${1}-sfw-lite.json
	python main.py ${SRV}.json templates/template-${1}-notun.json release/Sing-Box/${1}-lite-notun.json
	python main.py ${SRV}.json templates/template-${1}-sfw-notun.json release/Sing-Box/${1}-sfw-lite-notun.json
}

git clone https://github.com/SagerNet/serenity
cd serenity && make install 2> /dev/null && cd ..
serenity -c serenity.json run &

git clone https://github.com/SagerNet/sing-box
cd sing-box && git checkout main-next && make install 2> /dev/null && cd ..

curl -fsSL -o "${SRV}.json" http://localhost:8080/${SRV}

#quick-fix
sed -i s/\;mux\=true//g ${SRV}.json
sed -i s/mux\=true\;//g ${SRV}.json

exp cn && echo "CN files exported!"
exp ir && echo "IR files exported!"
exp ru && echo "RU files exported!"

for i in release/Sing-Box/*.json; do sing-box check -c "$i" && echo "'$i' is OK!"; done
rm ${SRV}.json
echo "SUCCESS!"

## Updating direct rule-set
sing-box rule-set format -w direct.json && sing-box rule-set compile direct.json && echo "Direct rule-set updated!"
sing-box rule-set format -w block.json && sing-box rule-set compile block.json && echo "Block rule-set updated!"
