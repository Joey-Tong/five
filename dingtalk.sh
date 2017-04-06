#!/bin/sh

token_url="https://oapi.dingtalk.com/robot/send?access_token=8156e8e64fded4144e1b9b073599af7a0a0ad0da69f80bf0cbaf1c851789c4a1"

ding_print()
{
	msg=$1

	curl -ks $token_url -H "Content-Type: application/json" -d " {\"msgtype\": \"text\", \"text\": { \"content\": \"$msg\" } }" >> /dev/null
}
