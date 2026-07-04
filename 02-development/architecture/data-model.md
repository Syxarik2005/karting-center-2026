# Схема данных клиентского приложения

> Дополняет `01-analysis/4-design/er-model-and-sequences.md` (там — модель со стороны
> аналитика/бэкенда). Здесь — как эти сущности живут во фронтенде: типы, откуда
> берутся, что из этого кэшируется react-query, что мутируется.

## 1. Сущности (1:1 с `01-analysis/api/openapi.yaml`)

```
Marshal
├── id, name, avatar_url, rating

Slot
├── id, start_time, track_config (SHORT|LONG)
├── marshal: Marshal
├── available_karts, max_karts
├── status (SCHEDULED|CANCELLED_BY_WEATHER|COMPLETED)
├── rental_tariff, gathering_place

Booking
├── id
├── slot: Slot   (снапшот слота на момент брони, не ссылка "вживую")
├── status (ACTIVE|CANCELLED_BY_CLIENT|CANCELLED_BY_CENTER|COMPLETED)
├── gear_type (OWN|RENTAL)
├── cancellation_reason?   (только при CANCELLED_BY_CENTER)
├── client_rating?          (клиентское поле — уже оценили маршала или нет)

ClientProfile
├── id, name, phone, is_regular
```

`client_rating` в `Booking` — единственное поле, которого нет в OpenAPI-контракте;
добавлено на фронте, чтобы решить чисто UI-задачу «показывать кнопку "Оценить
маршала" только один раз» без похода на сервер за списком уже оценённых броней.
Отмечено в коде (`types.ts`) как клиентское расширение, не часть контракта.

## 2. Откуда данные и как кэшируются (react-query)

| Query key | Функция | Инвалидируется при |
| --- | --- | --- |
| `['slots', horizonDays, track]` | `getSlots` | успешном/неуспешном `createBooking`, успешной `cancelBooking` |
| `['slot', slotId]` | `getSlot` | конфликте 409/410 при бронировании (пересинхронизация мест) |
| `['bookings']` | `getMyBookings` | `createBooking`, `cancelBooking` |
| `['booking', bookingId]` | `getBooking` | `cancelBooking`, `rateMarshal` |
| `['profile']` | `getProfile` | — (в этой поставке профиль read-only) |

## 3. Диаграмма связей

```
ClientProfile (1) ──< Booking >── (1) Slot ── (1) Marshal
                         │
                         └── gear_type, status, cancellation_reason, client_rating
```

Один `Slot` — много `Booking` (по числу занятых карт), но клиентское приложение
никогда не видит чужие брони — только свои (`GET /client/bookings`), поэтому
связь на фронте выглядит как 1:1 "моя бронь → слот", множественность скрыта на
бэкенде (`available_karts`/`max_karts` — это уже агрегат).
