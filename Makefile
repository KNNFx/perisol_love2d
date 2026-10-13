# Perisol - cua giao tiep duy nhat cho nguoi, agent va CI. Mac dinh: make help.
# Ghi de: make LOVE=/duong/dan/love LUA=luajit ...
LOVE ?= love
LUA  ?= luajit

N    ?= 100
BASE ?= 1
RICH ?=
ARGS ?=
NAME ?= shot.png
F    ?=

.DEFAULT_GOAL := help
.PHONY: help check layer test test-love sim sim-rich sweep repro cover hash hash-write run shot

help: ## Liet ke target
	@awk 'BEGIN{FS=":.*## "} /^[a-z-]+:.*## /{printf "  make %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check: layer test ## Cong truoc commit: lop + spec + golden hash + smoke sim + cover
	$(LUA) tools/hash.lua > /dev/null
	$(LUA) tools/sim.lua 10 > /dev/null
	$(LUA) tools/cover.lua

layer: ## src/core khong goi love.*; chi Wallet ghi .res, chi Rebel ghi vi tri Phien Quan, chi Roads ghi roads, chi Units them/xoa units
	@bad=$$(for f in src/core/*.lua; do sed 's/--.*$$//' $$f | grep -nE '(^|[^A-Za-z0-9_])love\.' | sed "s|^|$$f:|"; done); \
	if [ -n "$$bad" ]; then echo "FAIL: src/core goi love.*:"; echo "$$bad"; exit 1; fi; \
	echo "layer: src/core khong goi love.*"
	@bad=$$(for f in src/core/*.lua; do case $$f in src/core/wallet.lua|src/core/state.lua) continue;; esac; \
	  grep -nE '(^|[^A-Za-z0-9_])res(\[[^]]*\]|\.[A-Za-z_]+) *=[^=]' $$f | grep -v 'wallet:ok' | sed "s|^|$$f:|"; done); \
	if [ -n "$$bad" ]; then echo "FAIL: src/core ghi .res ngoai src/core/wallet.lua (dung Wallet.pay/gain/take; ngoai le danh dau 'wallet:ok'):"; echo "$$bad"; exit 1; fi; \
	echo "layer: moi lan ghi .res trong src/core di qua Wallet"
	@bad=$$(for f in src/core/*.lua; do case $$f in src/core/rebel.lua|src/core/state.lua) continue;; esac; \
	  grep -nE '\.rebel *(\.(q|r))?( *, *[A-Za-z_.]*rebel\.(q|r))? *(,[^=()]*)?=[^=]' $$f | grep -v 'rebel:ok' | sed "s|^|$$f:|"; done); \
	if [ -n "$$bad" ]; then echo "FAIL: src/core ghi vi tri Phien Quan ngoai src/core/rebel.lua (dung Rebel.moveTo; ngoai le danh dau 'rebel:ok'):"; echo "$$bad"; exit 1; fi; \
	echo "layer: vi tri Phien Quan chi ghi o rebel.lua"
	@bad=$$(for f in src/core/*.lua; do case $$f in src/core/roads.lua|src/core/state.lua) continue;; esac; \
	  grep -nE '\.roads(\[[^]]*\](\.[A-Za-z_]+)?)? *(,[^=()]*)?=[^=]' $$f | grep -v 'roads:ok' | sed "s|^|$$f:|"; done); \
	if [ -n "$$bad" ]; then echo "FAIL: src/core ghi state.roads ngoai src/core/roads.lua (dung Roads.build/upgrade/damage*; ngoai le danh dau 'roads:ok'):"; echo "$$bad"; exit 1; fi; \
	echo "layer: state.roads chi ghi o roads.lua"
	@bad=$$(for f in src/core/*.lua; do case $$f in src/core/units.lua|src/core/state.lua) continue;; esac; \
	  grep -nE '\.units(\[[^]]*\])? *(,[^=()]*)?=[^=]|\.nextUnitUid *=[^=]|table\.remove\([^)]*units' $$f | grep -v 'units:ok' | sed "s|^|$$f:|"; done); \
	if [ -n "$$bad" ]; then echo "FAIL: src/core them/xoa state.units ngoai src/core/units.lua (dung Units.spawn/remove; ngoai le danh dau 'units:ok'):"; echo "$$bad"; exit 1; fi; \
	echo "layer: state.units chi them/xoa o units.lua"

test: ## Spec bang luajit thuan (ca can LOVE duoc bo qua co khai bao)
	$(LUA) tools/test.lua

test-love: ## Toan bo spec trong LOVE (love . --test)
	$(LOVE) . --test

sim: ## Batch van ngau nhien: make sim N=100 [BASE=1]
	$(LUA) tools/sim.lua $(N) --base $(BASE)

sim-rich: ## Batch van nap day tai nguyen: make sim-rich N=10
	$(LUA) tools/sim.lua $(N) --base $(BASE) --rich

sweep: ## Quet dai seed, ghi build/repro/<seed>.lua khi loi: make sweep N=30 BASE=5000 [RICH=1]
	$(LUA) tools/sweep.lua $(N) $(BASE) $(if $(RICH),--rich,)

repro: ## Phat lai ca hong: make repro F=build/repro/5006.lua
	@test -n "$(F)" || { echo "thieu F=<file repro>"; exit 2; }
	$(LUA) tools/repro.lua $(F)

cover: ## Dem lenh/event trong batch co dinh, fail neu co loai chua phu ngoai danh sach khoang trong
	$(LUA) tools/cover.lua

hash: ## So hash state cuoi van voi tests/fixtures/golden_hashes.lua
	$(LUA) tools/hash.lua

hash-write: ## Sinh lai fixture golden (chi khi chu y doi luat/bot)
	$(LUA) tools/hash.lua write

run: ## Chay game: make run ARGS="--newgame --seed 5"
	$(LOVE) . $(ARGS)

shot: ## Chup man hinh: make shot NAME=a.png ARGS="--newgame"
	$(LOVE) . $(ARGS) --shot $(NAME)
