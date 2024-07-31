#!/usr/bin/env sh
export GOPROXY="https://proxy.golang.org,direct" GOAMD64='v3'
export SRV_FILE=final

function populate() {
	cp template-cn.json template-${1}.json; patch template-${1}.json ${1}.json.patch
	cp template-${1}.json template-${1}-sfw.json; cp template-${1}.json template-${1}-notun.json
	patch template-${1}-sfw.json sfw.json.patch; patch template-${1}-notun.json notun.json.patch
	cp template-${1}-sfw.json template-${1}-sfw-notun.json; patch template-${1}-sfw-notun.json notun.json.patch
}

function exp() {
	python main.py ${SRV_FILE}.json templates/template-${1}.json release/Sing-Box/${1}-lite.json
	python main.py ${SRV_FILE}.json templates/template-${1}-sfw.json release/Sing-Box/${1}-sfw-lite.json
	python main.py ${SRV_FILE}.json templates/template-${1}-notun.json release/Sing-Box/${1}-lite-notun.json
	python main.py ${SRV_FILE}.json templates/template-${1}-sfw-notun.json release/Sing-Box/${1}-sfw-lite-notun.json
}

git clone https://github.com/SagerNet/serenity
cd serenity && make install && cd ..
serenity -c serenity.json run &

git clone https://github.com/SagerNet/sing-box
cd sing-box && git checkout main-next && make install && cd ..

curl -fsSL -o "${SRV_FILE}.json" http://localhost:8080/${SRV_FILE}

#quick-fix
sed -i s/\;mux\=true//g ${SRV_FILE}.json
sed -i s/mux\=true\;//g ${SRV_FILE}.json

#populating templates
cd templates
populate cn
populate ir
populate ru
cd ..

exp cn && echo "CN files exported!"
exp ir && echo "IR files exported!"
exp ru && echo "RU files exported!"

for i in release/Sing-Box/*.json; do sing-box check -c "$i" && echo "'$i' is OK!"; done

echo "SUCCESS!"
