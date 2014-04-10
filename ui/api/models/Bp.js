/**
 * Bp
 *
 * @module      :: Model
 * @description :: A short summary of how this model works and what it represents.
 * @docs		:: http://sailsjs.org/#!documentation/models
 */

module.exports = {

  attributes: {
    id: {
      type: 'string',
      maxLength: 5,
      minLength: 1,
      required: 'true'
    },
    tools: {
      type: 'json'
    },
    defect_tracker: {
      type: 'json'
    },
    auth: {
      type: 'json'
    },
    projects: {
      type: 'json'
    },
    documentation: {
      type: 'json'
    },
    maestro_url: {
      type: 'string'
    }
  }

};
