#include <stdio.h>
#include <stdlib.h>
#include <sqlite3.h>
#include <time.h>

#define VECTOR_SIZE 16
#define NUM_RECORDS 100000

// Function to generate random vector data between -1.0 and 1.0
void generate_random_vector(float *vector, size_t size) {
    for (size_t i = 0; i < size; i++) {
        vector[i] = ((float)rand() / RAND_MAX) * 2.0f - 1.0f;
    }
}


int main() {
    sqlite3 *db;
    char *err_msg = NULL;
    int rc;

    // Seed the random number generator
    srand((unsigned int)time(NULL));

    // Open SQLite3 database
    rc = sqlite3_open("output/vectors.db", &db);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "Cannot open database: %s\n", sqlite3_errmsg(db));
        return 1;
    }

    // Create the vectors table
    const char *sql_create_table = 
        "CREATE TABLE IF NOT EXISTS vectors ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "vector BLOB,"
        "external_id INTEGER,"
        "level INTEGER);";

    printf("Creating table `vectors`...\n");
    rc = sqlite3_exec(db, sql_create_table, 0, 0, &err_msg);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "SQL error: %s\n", err_msg);
        sqlite3_free(err_msg);
        sqlite3_close(db);
        return 1;
    }

    // Create the index on level and external_id
    const char *sql_create_index = 
        "CREATE INDEX IF NOT EXISTS idx_level_external_id ON vectors (level, external_id);";

    rc = sqlite3_exec(db, sql_create_index, 0, 0, &err_msg);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "SQL error: %s\n", err_msg);
        sqlite3_free(err_msg);
        sqlite3_close(db);
        return 1;
    }

    // Prepare the insert statement
    const char *sql_insert = "INSERT INTO vectors (vector, external_id, level) VALUES (?, ?, ?);";
    sqlite3_stmt *stmt;
    rc = sqlite3_prepare_v2(db, sql_insert, -1, &stmt, 0);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "Failed to prepare statement: %s\n", sqlite3_errmsg(db));
        sqlite3_close(db);
        return 1;
    }

    // Generate random vectors and insert them into the database
    float vector[VECTOR_SIZE];
    clock_t start_time = clock();

    for (int i = 0; i < NUM_RECORDS; i++) {
        generate_random_vector(vector, VECTOR_SIZE);

        sqlite3_bind_blob(stmt, 1, vector, VECTOR_SIZE, SQLITE_STATIC);
        sqlite3_bind_int(stmt, 2, rand() % 1000);  // Random external_id
        sqlite3_bind_int(stmt, 3, rand() % 10);    // Random level

        rc = sqlite3_step(stmt);
        if (rc != SQLITE_DONE) {
            fprintf(stderr, "Execution failed: %s\n", sqlite3_errmsg(db));
            sqlite3_finalize(stmt);
            sqlite3_close(db);
            return 1;
        }

        sqlite3_reset(stmt);
    }

    clock_t end_time = clock();
    double elapsed_time = (double)(end_time - start_time) / CLOCKS_PER_SEC;
    printf("Inserted %d records in %.2f seconds.\n", NUM_RECORDS, elapsed_time);

    // Finalize the statement and close the database
    sqlite3_finalize(stmt);
    sqlite3_close(db);

    return 0;
}
