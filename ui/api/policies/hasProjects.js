/**
    (c) Copyright 2014 Hewlett-Packard Development Company, L.P.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/
var blueprint_utils = require('blueprint/blueprint');
module.exports = function(req, res, next) {

  // User is allowed, proceed to the next policy,
  // or if this is the last policy, the controller
  blueprint_utils.get_blueprint_id(function(error){
      console.error('Unable to get the instance_id of the kit (hasprojects): '+error.message);
      req.session.projects = false;
      return next();
  }, function(result){
      result = JSON.parse(result);
      blueprint_utils.get_blueprint_section(result.id, 'projects', function(err){
        console.error('Unable to check if maestro has projects enabled: '+err.message);
        req.session.projects = false;
        return next();
      }, function(projects){
        projects = JSON.parse(projects);
        req.session.projects = projects!==0?true:false;
        return next();
      });
  });
};