# BUG-002 — Добавление Vitest сломало прод-сборку (`npm run build`)

## Симптом / цель
После настройки Vitest (`test` секция в `vite.config.ts`) команда
`npm run build` перестала работать:

```
vite.config.ts(7,3): error TS2769: No overload matches this call.
  The last overload gave the following error.
    Object literal may only specify known properties, and 'test' does not
    exist in type 'UserConfigExport'.
```

## Требования
`npm run build` (`tsc -b && vite build`) должен продолжать проходить после
добавления тестовой инфраструктуры — тесты не должны быть ценой рабочей
прод-сборки.

## Причина
`vite.config.ts` типизирован через `defineConfig` из пакета `vite`, который
ничего не знает про ключ `test` (это расширение из `vitest/config`). TS
корректно ругался — конфиг был синтаксически рабочим для самого Vite в
рантайме, но не проходил проверку типов на `tsc -b` шаге сборки.

## Исправление
Добавлена трипл-слэш директива `/// <reference types="vitest/config" />` в
начало `vite.config.ts` — она подключает расширенные типы `UserConfigExport`
с полем `test`, ничего не меняя в рантайм-поведении.

## Промпты (переданные ИИ-ассистенту)
```
1. "После добавления test-секции в vite.config.ts сборка (tsc -b) падает с
    TS2769 про неизвестное поле 'test'. Почини типы конфига, не трогая
    рантайм-поведение Vite."
```

## Ручная проверка
1. `npm run build` в `02-development/client` — проходит без ошибок TS.
2. `npm test` — все 18 тест-кейсов по-прежнему проходят (изменение чисто в
   типах, логика тестов не менялась).

## Коммит
`fix(client): починить tsc-сборку после добавления Vitest (BUG-002)`
