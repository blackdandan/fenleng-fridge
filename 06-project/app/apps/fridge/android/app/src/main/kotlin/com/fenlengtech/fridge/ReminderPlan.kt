package com.fenlengtech.fridge

import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

internal data class ReminderCycle(val key: String, val day: String, val hour: Int,
    val minute: Int, val second: Int, val millisecond: Int) {
    fun at(): Long {
        val parts = day.split('-').map(String::toInt)
        return Calendar.getInstance().apply {
            clear(); set(parts[0], parts[1] - 1, parts[2], hour, minute, second)
            set(Calendar.MILLISECOND, millisecond)
        }.timeInMillis
    }
    fun json() = JSONObject().put("key", key).put("day", day).put("hour", hour)
        .put("minute", minute).put("second", second).put("millisecond", millisecond)

    companion object {
        fun parse(value: JSONObject): ReminderCycle {
            val key = value.getString("key"); val day = value.getString("day")
            val hour = value.getInt("hour"); val minute = value.getInt("minute")
            val second = value.getInt("second"); val millisecond = value.optInt("millisecond", 0)
            require(key.isNotBlank() && key.length <= 512 && day.matches(Regex("\\d{4}-\\d{2}-\\d{2}")))
            require(hour in 0..23 && minute in 0..59 && second in 0..59 && millisecond in 0..1000)
            val parts = day.split('-').map(String::toInt)
            Calendar.getInstance().apply {
                clear(); isLenient = false; set(parts[0], parts[1] - 1, parts[2]); timeInMillis
            }
            return ReminderCycle(key, day, hour, minute, second, millisecond)
        }
        fun list(values: JSONArray): List<ReminderCycle> = (0 until values.length())
            .map { parse(values.getJSONObject(it)) }.also { values -> require(values.map { it.key }.toSet().size == values.size) }
    }
}

internal data class ReminderCopy(val title: String, val body: String, val channel: String, val locale: String) {
    fun json() = JSONObject().put("title", title).put("body", body).put("channel", channel).put("locale", locale)
    companion object {
        fun parse(value: JSONObject): ReminderCopy {
            val copy = ReminderCopy(value.getString("title"), value.getString("body"), value.getString("channel"), value.getString("locale"))
            require(copy.title.isNotBlank() && copy.title.length <= 256 && copy.body.contains("{count}") && copy.body.length <= 1024)
            require(copy.channel.isNotBlank() && copy.channel.length <= 128 && copy.locale.length <= 32)
            return copy
        }
    }
}
