CREATE TABLE experiment (
                            id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

                            name VARCHAR(255) NOT NULL,
                            description TEXT,
                            script TEXT,
                            timeout_seconds INTEGER,

                            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

                            CONSTRAINT chk_experiment_timeout
                                CHECK (timeout_seconds IS NULL OR timeout_seconds > 0)
);


CREATE TABLE experiment_dependency (
                                       id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

                                       experiment_id BIGINT NOT NULL,

                                       package_name VARCHAR(255) NOT NULL,
                                       version_constraint VARCHAR(100),

                                       created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

                                       CONSTRAINT fk_dependency_experiment
                                           FOREIGN KEY (experiment_id)
                                               REFERENCES experiment(id)
                                               ON DELETE CASCADE,

                                       CONSTRAINT uq_experiment_dependency
                                           UNIQUE (experiment_id, package_name)
);


CREATE TABLE execution (
                           id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

                           experiment_id BIGINT NOT NULL,

                           status VARCHAR(20) NOT NULL DEFAULT 'CREATED',

                           timeout_seconds INTEGER NOT NULL,

                           exit_code INTEGER,

                           error_message TEXT,

                           stdout_log TEXT,
                           stderr_log TEXT,

                           created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
                           started_at TIMESTAMP WITH TIME ZONE,
                           finished_at TIMESTAMP WITH TIME ZONE,

                           CONSTRAINT fk_execution_experiment
                               FOREIGN KEY (experiment_id)
                                   REFERENCES experiment(id)
                                   ON DELETE CASCADE,

                           CONSTRAINT chk_execution_status
                               CHECK (
                                   status IN (
                                              'CREATED',
                                              'RUNNING',
                                              'SUCCESS',
                                              'FAILED',
                                              'TIMEOUT',
                                              'CANCELLED'
                                       )
                                   ),

                           CONSTRAINT chk_execution_timeout
                               CHECK (timeout_seconds > 0),

                           CONSTRAINT chk_execution_dates
                               CHECK (
                                   finished_at IS NULL
                                       OR started_at IS NULL
                                       OR finished_at >= started_at
                                   )
);


CREATE TABLE result (
                        id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

                        execution_id BIGINT NOT NULL,

                        name VARCHAR(255) NOT NULL,

                        type VARCHAR(20) NOT NULL,

                        content TEXT,

                        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

                        CONSTRAINT fk_result_execution
                            FOREIGN KEY (execution_id)
                                REFERENCES execution(id)
                                ON DELETE CASCADE,

                        CONSTRAINT chk_result_type
                            CHECK (
                                type IN (
                                         'TEXT',
                                         'NUMBER',
                                         'MARKDOWN',
                                         'HTML'
                                    )
                                )
);


-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_execution_experiment
    ON execution(experiment_id);

CREATE INDEX idx_execution_status
    ON execution(status);

CREATE INDEX idx_execution_experiment_created
    ON execution(experiment_id, created_at DESC);

CREATE INDEX idx_result_execution
    ON result(execution_id);

CREATE INDEX idx_dependency_experiment
    ON experiment_dependency(experiment_id);