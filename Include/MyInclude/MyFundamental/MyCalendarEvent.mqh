

class MyCalendarEvent
{
    public:
        MyCalendarEvent::MyCalendarEvent(MqlCalendarEvent &mql_calendar_event, MqlCalendarValue &mql_calendar_value);
        MyCalendarEvent::~MyCalendarEvent();

        string MyCalendarEvent::GetEventName();
        ulong MyCalendarEvent::GetEventId();
        ulong MyCalendarEvent::GetCountryId();
        datetime MyCalendarEvent::GetEventDatetime();
        ENUM_CALENDAR_EVENT_IMPORTANCE MyCalendarEvent::GetEventImportance();
        bool MyCalendarEvent::CanGetEventDatetime();

    public:
        // MqlCalendarEvent構造体の項目
        ulong event_id;
        ENUM_CALENDAR_EVENT_TYPE event_type;  // https://www.mql5.com/ja/docs/constants/structures/mqlcalendar#enum_calendar_event_type
        ENUM_CALENDAR_EVENT_SECTOR event_sector;  // https://www.mql5.com/ja/docs/constants/structures/mqlcalendar#enum_calendar_event_sector
        ENUM_CALENDAR_EVENT_FREQUENCY event_frequency;  // https://www.mql5.com/ja/docs/constants/structures/mqlcalendar#enum_calendar_event_frequency
        ENUM_CALENDAR_EVENT_TIMEMODE event_timemode;  // https://www.mql5.com/ja/docs/constants/structures/mqlcalendar#enum_calendar_event_timemode
        ulong country_id;
        ENUM_CALENDAR_EVENT_UNIT event_unit;  // https://www.mql5.com/ja/docs/constants/structures/mqlcalendar#enum_calendar_event_unit
        ENUM_CALENDAR_EVENT_IMPORTANCE event_importance;  // https://www.mql5.com/ja/docs/constants/structures/mqlcalendar#enum_calendar_event_importance
        uint digits;
        string source_url;
        string event_code;
        string event_name;

        // MqlCalendarValue構造体の項目
        ulong value_id;
        datetime event_datetime;
        datetime event_period_datetime;
        int revision;
        long actual_value;
        long prev_value;
        long revised_prev_value;
        long forecast_value;
        ENUM_CALENDAR_EVENT_IMPACT impact_type;  // https://www.mql5.com/ja/docs/constants/structures/mqlcalendar#enum_calendar_event_impact

};

MyCalendarEvent::MyCalendarEvent(MqlCalendarEvent &mql_calendar_event, MqlCalendarValue &mql_calendar_value) {
    // assert(mql_calendar_event.id == mql_calendar_value.event_id, StringFormat("[ERROR] InValid event id,  MqlCalendarEvent event_id=%d, MqlCalendarValue event_id=%d", mql_calendar_event.id, mql_calendar_value.event_id));
    event_id = mql_calendar_event.id;
    event_type = mql_calendar_event.type;
    event_sector = mql_calendar_event.sector;
    event_frequency = mql_calendar_event.frequency;
    event_timemode = mql_calendar_event.time_mode;
    country_id = mql_calendar_event.country_id;
    event_unit = mql_calendar_event.unit;
    event_importance = mql_calendar_event.importance;
    digits = mql_calendar_event.digits;
    source_url = mql_calendar_event.source_url;
    event_code = mql_calendar_event.event_code;
    event_name = mql_calendar_event.name;

    value_id = mql_calendar_value.id;
    event_datetime = mql_calendar_value.time;
    event_period_datetime = mql_calendar_value.period;
    revision = mql_calendar_value.revision;
    actual_value = mql_calendar_value.actual_value;
    prev_value = mql_calendar_value.prev_value;
    revised_prev_value = mql_calendar_value.revised_prev_value;
    forecast_value = mql_calendar_value.forecast_value;
    impact_type = mql_calendar_value.impact_type;
}

MyCalendarEvent::~MyCalendarEvent() {

}

string MyCalendarEvent::GetEventName() {
    return this.event_name;
}

ulong MyCalendarEvent::GetEventId() {
    return this.event_id;
}

ulong MyCalendarEvent::GetCountryId() {
    return this.country_id;
}

datetime MyCalendarEvent::GetEventDatetime() {
    return this.event_datetime;
}

ENUM_CALENDAR_EVENT_IMPORTANCE MyCalendarEvent::GetEventImportance() {
    return this.event_importance;
}

bool MyCalendarEvent::CanGetEventDatetime() {
    return this.event_timemode == CALENDAR_TIMEMODE_DATETIME;
}