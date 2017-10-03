#ifndef DATALOG_H
#define DATALOG_H

#define NR_INFO_LOG_ENTRIES 5
#define INFO_LOG_ENTRY_FIELD_LEN 32

struct info_log_entry {
    char username[INFO_LOG_ENTRY_FIELD_LEN];
    char password[INFO_LOG_ENTRY_FIELD_LEN];
    char url[INFO_LOG_ENTRY_FIELD_LEN];
    int valid;
};

struct info_log {
    struct info_log_entry entries[NR_INFO_LOG_ENTRIES];
    unsigned crc32;
};

interface info_log_if {
    void add_entry(char username[INFO_LOG_ENTRY_FIELD_LEN], char password[INFO_LOG_ENTRY_FIELD_LEN], char url[INFO_LOG_ENTRY_FIELD_LEN]);
};

#endif // DATALOG_H
