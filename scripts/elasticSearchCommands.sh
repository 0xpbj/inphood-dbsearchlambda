#!/bin/bash -eu
#   -e:  Exit immed. if cmd. returns non-zero status.
#   -u:  Unset vars treated as error on substitution.
#
#es_host='localhost'
es_host='35.167.212.47'
es_port='9200'
es_instance="$es_host:$es_port"
es_database='firebase'


#
# GENERAL ELASTICSEARCH CLUSTER & INDEX COMMANDS
################################################################################

alias es_cluster_health="curl $es_instance/_cluster/health?pretty"

alias es_index_status="curl -XGET '$es_instance/_all/_settings?pretty'"
alias es_index_open="curl -XPOST '$es_instance/$es_database/_open?pretty'"
alias es_index_close="curl -XPOST '$es_instance/$es_database/_close?pretty'"

alias es_index_delete="curl -XDELETE '$es_instance/$es_database?pretty'"
#
# ELASTICSEARCH INDEX CONFIGURATION
################################################################################

# get_es_indexing_config:
# ----------------------------------------
#
get_es_indexing_configuration() {
  echo " \
{\
  \"analysis\" : {
    \"filter\": {
      \"english_stop\" : {
        \"type\" : \"stop\",
        \"stopwords\" : \"_english_\"
      },
      \"light_english_stemmer\" : {
        \"type\" : \"stemmer\",
        \"language\" : \"light_english\"
      }
    },
    \"analyzer\" : {
      \"english\" : {
        \"tokenizer\" : \"standard\",
        \"filter\" : [
          \"lowercase\",
          \"porter_stem\",
          \"english_stop\",
          \"light_english_stemmer\"
        ]
      }
    }
  }
}"
}

es_configure_indexing() {
  curl -XPOST "$es_instance/$es_database/_close?pretty"

  curl -XPUT "$es_instance/$es_database/_settings" -d "$( get_es_indexing_configuration )"

  curl -XPOST "$es_instance/$es_database/_open?pretty"
}


#
# ELASTICSEARCH TEMPLATE CONFIGURATION
################################################################################

# get_es_firebase_index_template:
# ----------------------------------------
#
#   For info on similarity:
#     - http://stackoverflow.com/questions/27307291/bm25-similarity-tuning-in-elasticsearch
#     - https://www.elastic.co/guide/en/elasticsearch/guide/current/pluggable-similarites.html#bm25-tunability
#     - https://www.elastic.co/guide/en/elasticsearch/reference/current/index-modules-similarity.html
#
get_es_firebase_index_template() {
  echo " \
{\
  \"template\" : \"firebase\",
  \"settings\": {
    \"analysis\" : {
      \"filter\": {
        \"english_stop\" : {
          \"type\" : \"stop\",
          \"stopwords\" : \"_english_\"
        },
        \"light_english_stemmer\" : {
          \"type\" : \"stemmer\",
          \"language\" : \"light_english\"
        }
      },
      \"analyzer\" : {
        \"description_analyzer\" : {
          \"tokenizer\" : \"standard\",
          \"filter\" : [
            \"lowercase\",
            \"porter_stem\",
            \"english_stop\",
            \"light_english_stemmer\"
          ]
        }
      }
    },
    \"similarity\" : {
      \"inPhood_bm25\" : {
        \"type\" : \"BM25\",
        \"k1\" : \"1.2\",
        \"b\" : \"1.0\"
      }
    }
  },
  \"mappings\" : {
    \"NutritionInfo\" : {
      \"properties\" : {
        \"Description\" : {
          \"analyzer\" :  \"description_analyzer\",
          \"type\" : \"string\",
          \"fields\" : {
            \"raw\" : {
              \"type\" : \"string\",
              \"analyzer\" : \"whitespace\"
            }
          }
        },
        \"inPhood001\" : {
          \"analyzer\" : \"description_analyzer\",
          \"type\" : \"string\",
          \"fields\" : {
            \"raw\" : {
              \"type\" : \"string\",
              \"analyzer\" : \"whitespace\"
            }
          }
        }
      }
    } 
  }
}"
}


alias es_set_firebase_template="curl -XPUT '$es_instance/_template/firebase_template?pretty' -H 'Content-Type: application/json' -d '$( get_es_firebase_index_template )'"
alias es_get_firebase_template="curl -XGET '$es_instance/_template/firebase_template?pretty'"
alias es_rm_firebase_template="curl -XDELETE '$es_instance/_template/firebase_template?pretty'"

#
# ELASTICSEARCH TEST QUERIES
################################################################################

# get_es_query_match:
# ----------------------------------------
# The actual query string is passed in as the first argument ($1)
#
get_es_query_match() {
  echo " \
{\
  \"query\": {\
    \"match\" : {\
      \"Description\" : {\
        \"query\" : \"$1\",\
        \"analyzer\" : \"description_analyzer\"\
      }\
    }\
  }\
}"
}

get_es_query_span_first() {
  echo " \
{\
  \"query\": {\
    \"span_first\" : {\
      \"match\" : {\
        \"span_term\" : {\"Description\" : \"$1\" }\
      },\
      \"end\" : 4\
    }\
  }\
}"
}

es_match() {
  curl -XPOST "$es_instance/firebase/_search?pretty" -d "$(get_es_query_match "$1" )"
}


es_span_first() {
  curl -XPOST "$es_instance/firebase/_search?pretty" -d "$(get_es_query_span_first "$1" )"
}

# get_es_query_multi_match:
# ----------------------------------------
# The actual query string is passed in as the first argument ($1)
#
#   Was: \"fields\" : [\"Description\", \"inPhood001\"],\

get_es_query_multi_match() {
  echo " \
{\
  \"query\" : {\
    \"multi_match\" : {\
      \"query\" : \"$1\",\
      \"fields\" : [\"Description\"],\
      \"type\" : \"best_fields\",\
      \"operator\" : \"or\"\
    }\
  },\
  \"fielddata_fields\" : [ \
    \"Description\" \
  ] \
}"
}

get_es_query_bool_multi_match() {
  echo " \
{\
  \"query\" : {\
    \"bool\" : {\
      \"must\" : [\
        {\
          \"multi_match\" : {\
            \"query\" : \"$1\",\
            \"fields\" : [\"Description\"],\
            \"type\" : \"best_fields\",\
            \"operator\" : \"or\"\
          }\
        }\
      ],\
      \"should\" : [\
        {\
          \"span_first\" : {\
            \"match\" : {\
              \"span_term\" : {\
                \"Description\" : \"$1\"\
              }\
            },\
            \"end\" : 1\
          }\
        },\
        {\
          \"match\" : {\
            \"Description\" : \"raw\"\
          }\
        },\
        {\
          \"match\" : {\
            \"Description\" : \"tap\"\
          }\
        }\
      ]\
    }\
  },\
  \"highlight\" : {\
    \"fields\" : {\
      \"Description\" : {}\
    }\
  },\
  \"fielddata_fields\" : [ \
    \"Description\" \
  ] \
}"
}

#get_es_query_laser_match() {
#  echo " \
#{
#  \"query\" : {
#    \"bool\" : {
#      \"must\" : [
#        {
#          \"match\" : {
#            \"inPhood001\" : {
#              \"query\" : \"$1\",
#              \"analyzer\" : \"description_analyzer\"
#            }
#          }
#        }
#      ],
#      \"should\" : [
#        {
#          \"match\" : {\
#            \"Description\" : {
#              \"query\" : \"$1\",
#              \"analyzer\" : \"description_analyzer\"
#            }
#          }
#        }
#      ]
#    }
#  },
#  \"highlight\" : {
#    \"fields\" : {
#      \"Description\" : {}
#    }
#  },
#  \"fielddata_fields\" : [ 
#    \"Description\" 
#  ] 
#}"
#}
#
get_es_query_laser_match() {
  echo " \
{
  \"query\" : {
    \"bool\" : {
      \"filter\" : {
        \"match\" : {
          \"inPhood001\" : {
            \"query\" : \"$1\",
            \"analyzer\" : \"description_analyzer\"
          }
        }
      },
      \"should\" : [
        {
          \"match\" : {\
            \"Description\" : {
              \"query\" : \"$1\",
              \"analyzer\" : \"description_analyzer\"
            }
          }
        },
        {
          \"match\" : {
            \"Description\" : {
              \"query\" : \"tap\"
            }
          }
        }
      ]
    }
  },
  \"highlight\" : {
    \"fields\" : {
      \"Description\" : {}
    }
  },
  \"fielddata_fields\" : [ 
    \"Description\" 
  ] 
}"
}

get_es_query_laser_match_test () {
  echo " \
{
  \"query\" : {
    \"bool\" : {
      \"filter\" : {
        \"match\" : {
          \"inPhood001\" : {
            \"query\" : \"$1\",
            \"analyzer\" : \"description_analyzer\"
          }
        }
      },
      \"should\" : [
        {
          \"match\" : {
            \"Description\" : {
              \"query\" : \"$1\",
              \"analyzer\" : \"description_analyzer\"
            }
          }
        },
        {
          \"match\" : {
            \"Description\" : {
              \"query\" : \"tap\"
            }
          }
        }
      ]
    }
  }
}"
}

es_multi_match() {
  curl -XPOST "$es_instance/firebase/_search?pretty" -d "$(get_es_query_multi_match "$1" )"
}

es_heuristic_match() {
  curl -XPOST "$es_instance/firebase/_search?pretty" -d "$( get_es_query_bool_multi_match "$1" )"
}

es_laser_match() {
  curl -XPOST "$es_instance/firebase/_search?pretty" -d "$( get_es_query_laser_match "$1" )"

}

# Pass this a search term and the result in the db to get an explanation of the scoring, e.g.:
#
#   es_laser_explain water 14411
#
es_laser_explain() {
  curl -XGET "$es_instance/firebase/NutritionInfo/$2/_explain?format=yaml" -d "$( get_es_query_laser_match_test "$1" )"
}

es_laser_validate() {
  curl -XGET "$es_instance/firebase/_validate/query?explain&pretty" -d "$( get_es_query_laser_match "$1" )"
}

alias es_multi_match_avocado="curl -XPOST '$es_instance/firebase/_search?pretty' -d '$( get_es_query_multi_match avocado )'"
alias es_match_avocado="curl -XGET '$es_instance/_search?pretty' -d '$( get_es_query_match avocado )'"
