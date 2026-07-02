# ER-модель и диаграммы последовательности (Архитектура клиента)

В данном документе описана модель данных клиентского мобильного приложения и диаграмма последовательности для ключевого процесса — создания бронирования заезда.

## 1. ER-модель (в контексте клиентского приложения)

Важно: Клиентское приложение не является мастером-источником большинства данных. Оно выступает как потребитель (Consumer) API.

### Сущности от сервера (Read-Only)
Эти данные приходят от бэкенда и не могут быть изменены клиентом напрямую (только через вызов соответствующих API-методов, если это предусмотрено).

*   **Slot (Заезд)**
    *   `id`: UUID
    *   `start_time`: DateTime
    *   `track_config`: Enum (SHORT, LONG)
    *   `marshal`: Object (ID, Name, Avatar, Rating)
    *   `available_karts`: Integer
    *   `max_karts`: Integer
    *   `status`: Enum (SCHEDULED, CANCELLED_BY_WEATHER, COMPLETED)
*   **Booking (Бронирование)**
    *   `id`: UUID
    *   `slot_id`: UUID
    *   `client_id`: UUID
    *   `status`: Enum (ACTIVE, CANCELLED_BY_CLIENT, CANCELLED_BY_CENTER, COMPLETED)
    *   `gear_type`: Enum (OWN, RENTAL)
*   **ClientProfile (Профиль клиента)**
    *   `id`: UUID
    *   `phone`: String
    *   `name`: String
    *   `is_regular`: Boolean

### Локальное состояние (Read-Write)
*   **DraftBooking (Черновик бронирования)** — хранится в ОЗУ на экране `SCR-002`.
    *   `slot_id`: UUID
    *   `selected_gear_type`: Enum
*   **FiltersState (Состояние фильтров)** — на экране `SCR-001`.
    *   `selected_date`: Date
    *   `selected_track_config`: Enum

---

## 2. Sequence Diagram: Создание бронирования (createBooking)

Диаграмма описывает взаимодействие между клиентом (пользователем), мобильным приложением и бэкендом (API) при попытке записаться на заезд. 
Бэкенд выступает black-box системой, гарантирующей отсутствие двойных бронирований.

```mermaid
sequenceDiagram
    actor User as Клиент
    participant App as Мобильное приложение
    participant API as Бэкенд (API)

    User->>App: Нажимает «Записаться» (SCR-002)
    App->>App: Валидация формы (выбрана экипировка)
    App->>App: Показ индикатора загрузки (Submitting)
    App->>API: POST /api/bookings { slotId, gearType }
    
    alt Успешное бронирование (Места есть)
        API-->>App: 201 Created { bookingId, status: ACTIVE }
        App->>App: Скрытие индикатора загрузки
        App->>User: Переход на SCR-004 (Детали бронирования)
        
    else Конфликт (Места закончились)
        API-->>App: 409 Conflict { code: "NO_AVAILABLE_KARTS" }
        App->>App: Скрытие индикатора загрузки
        App->>User: Показ алерта "Места закончились" на SCR-002
        App->>API: GET /api/slots/{slotId} (Обновление инфы о слоте)
        API-->>App: 200 OK { available_karts: 0 }
        App->>App: Обновление UI (блокировка кнопки "Записаться")
        
    else Слот недоступен (Отменен центром / удален)
        API-->>App: 410 Gone { code: "SLOT_UNAVAILABLE" }
        App->>App: Скрытие индикатора загрузки
        App->>User: Показ алерта "Заезд был отменен"
        App->>User: Возврат на SCR-001 (Расписание)
        App->>API: GET /api/slots (Обновление списка слотов)
    end
```
