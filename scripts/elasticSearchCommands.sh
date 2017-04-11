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
      },      \"light_english_stemmer\" : {
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
    }
  },
  \"mappings\" : {
    \"NutritionInfo\" : {
      \"properties\" : {
        \"Description\" : {
          \"analyzer\" :  \"description_analyzer\",
          \"type\" : \"string\"
        }
      }
    } 
  }
}"
}


alias es_set_firebase_template="curl -XPUT '$es_instance/_template/firebase_template?pretty' -H 'Content-Type: application/json' -d '$( get_es_firebase_index_template )'"
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
  }\
}"
}

es_multi_match() {
  curl -XPOST "$es_instance/firebase/_search?pretty" -d "$(get_es_query_multi_match "$1" )"
}

es_heuristic_match() {
  curl -XPOST "$es_instance/firebase/_search?pretty" -d "$( get_es_query_bool_multi_match "$1" )"
}

alias es_multi_match_avocado="curl -XPOST '$es_instance/firebase/_search?pretty' -d '$( get_es_query_multi_match avocado )'"
alias es_match_avocado="curl -XGET '$es_instance/_search?pretty' -d '$( get_es_query_match avocado )'"
