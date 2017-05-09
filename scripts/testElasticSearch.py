#!/usr/local/bin/python
#
# Need /usr/local/bin/python vs. /usr/bin/python b/c the Apple python doesn't seem
# to see packages installed via pip.

# What this does:
# Given a text file of search queries and their expected result, curl our elastic
# search server to get results using the current query/configuration and score
# the results to evaluate performance.

import getopt, sys, re, requests, json

def getQueryDSL(query):
  quotedQuery = '"' + query + '"'
  dsl = json.dumps({
    'query' : {
      'bool' : {
        'must' : [
          {
            'multi_match' : {
              'query' : quotedQuery,
              'fields' : ['Description'],
              'type' : 'best_fields',
              'operator' : 'or'
            }
          }
        ],
        'should' : [
          {
            'span_first' : {
              'match' : {
                'span_term' : {
                  'Description' : quotedQuery 
                }
              },
              'end' : 1
            }
          },
          {
            'match' : {
              'Description' : {
                'query' : 'raw'
              }
            }
          },
          {
            'match' : {
              'Description' : {
                'query' : 'tap'
              }
            }
          }
        ]
      }
    },
    'highlight' : {
      'pre_tags': [
        "<strong>"
      ],
      'post_tags': [
        "</strong>"
      ],
      'fields' : {
        'Description' : {}
      }
    }
  })
  return dsl

def getQueryDSL_v2(query):
  quotedQuery = '"' + query + '"'
  dsl = json.dumps({
    'query' : {
      'bool' : {
        'filter' : {
          'match' : {
            'inPhood001' : {
              'query' : quotedQuery,
              'analyzer' : 'description_analyzer'
            }
          }
        },
        'should' : [
          {
            'match' : {
              'Description' : {
                'query' : quotedQuery,
                'analyzer' : 'description_analyzer'
              }
            }
          },
          {
            'match' : {
              'Description' : {
                'query' : 'tap'
              }
            }
          },
        ],
        'must_not' : {
          'match' : {
            'Description' : {
              'query' : 'meatless'
            }
          }
        }
      }
    },
    'highlight' : {
      'pre_tags': [
        "<strong>"
      ],
      'post_tags': [
        "</strong>"
      ],
      'fields' : {
        'Description' : {}
      }
    }
  })
  return dsl

positionScoreDict = {
  1: 100,
  2: 50,
  3: 40,
  4: 30,
  5: 20,
  6: 10,
  7: 10,
  8: 10,
  9: 10,
  10: 10
}

def getScore(position, found):
  # Practical solution is score based on if the item is in the top 5 results:
  #   for instance score = 100% item in position 1
  #                      =  50% item in position 2
  #                      =  40% item in position 3
  #                      ...
  #                      =  20% item in position 5
  #                      =  10% item in top 10
  #                      =   0% otherwise
  #
  if (found): 
    return positionScoreDict.get(position, 0)

  return 0

def main(scriptName, argv):
  # Usage / help / argument processing:
  #
  usageString = 'Usage: ' + scriptName + ' - f <testFilePath> [-d][-n="note"]'
  detailedOutput = False
  testFilePath = ''
  note = ''

  try:
    opts, args = getopt.getopt(sys.argv[1:], "hdf:n:", ["testFilePath=", "note="])
  except getopt.GetoptError:
    print usageString
    sys.exit()

  for opt, arg in opts:
    if opt == '-h':
      print usageString
      sys.exit()
    elif opt in ('-d', "--detailedOutput"):
      detailedOutput = True
    elif opt in ("-f", "--testFilePath"):
      testFilePath = arg
      if (testFilePath == ''):
        print usageString
        sys.exit()
    elif opt in ("-n", "--note"):
      note = arg
    else:
      print usageString
      sys.exit()

  if (testFilePath == ''):
    print usageString
    sys.exit()

  combinedScore = 0
  maxCombinedScore = 0
  detailedResult = ""
  # Read in a text file of search query / expected result pairs, iterate over each
  # line computing the search result scores:
  #
  with open(testFilePath, 'rb') as testFile:
    for line in testFile:
      maxCombinedScore += 100

      # Find quote delimited fields--first one is the query, second is the expected result
      matches = re.findall('".*?"', line)
      if (len(matches) != 2):
        raise Exception('Unexpected input from ' + testFilePath + ': ' + line)
      query = matches[0].translate(None, '"')
      expected = matches[1].translate(None, '"')

      # Now send a request to our elastic search server for the query:
      #
      response = requests.post('http://35.167.212.47:9200/firebase/_search?pretty', data=getQueryDSL_v2(query))
      obj = json.loads(response.content)

      # Now iterate over the results and determine the position of the 
      # query in the results:
      position = 0
      found = False
      detailedResult += query + " (expecting: \"" + expected + "\"):\n"
      for result in obj["hits"]["hits"]:
        position += 1
        description = result["_source"]["Description"]
        detailedResult += "   " + description + " (id=" + str(result["_id"]) + ", score=" + str(result["_score"]) + ")\n"
        if description.lower() == expected.lower():
          found = True
          break
        elif position == 10:
          break
      detailedResult += "\n"

      # Compute the search result score:
      #
      score = getScore(position, found)
      combinedScore += score

    print ""
    print "Combined test result: " + str(combinedScore) + " / " + str(maxCombinedScore)
    if (note != ''):
      print "(" + note + ")"
    print "--------------------------------------------------------------------------------"
    print ""

    if detailedOutput:
      print detailedResult


if __name__ == "__main__":
  main(sys.argv[0], sys.argv[1:])
