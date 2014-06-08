/*
 *   Copyright 2014 Hewlett-Packard Development Company, L.P.
 *
 *   Licensed under the Apache License, Version 2.0 (the "License");
 *   you may not use this file except in compliance with the License.
 *   You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *   Unless required by applicable law or agreed to in writing, software
 *   distributed under the License is distributed on an "AS IS" BASIS,
 *   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *   See the License for the specific language governing permissions and
 *   limitations under the License. 
 *
 * create user (i.e. the service account)
 */

GRANT ALL ON kit_bp.* TO 'kitusr'@'localhost' IDENTIFIED BY '$Changeme01';

/*
 * kit_bp database
 */

CREATE DATABASE IF NOT EXISTS `kit_bp`;

/*
 * table: kit_bp
 */

USE kit_bp;

CREATE TABLE IF NOT EXISTS `kit_bp`.`blueprints` (
  `id` VARCHAR(5) NOT NULL,
  `tools` TEXT NULL,
  `defect_tracker` TEXT NULL,
  `auth` TEXT NULL,
  `users` TEXT NULL,
  `projects` TEXT NULL,
  `documentation` TEXT NULL,
  `createdAt` TIMESTAMP NULL,
  `updatedAt` TIMESTAMP NULL,
  PRIMARY KEY (`id`));
