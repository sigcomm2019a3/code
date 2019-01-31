#include <cstdio>
#include <vector>
#include <algorithm>
#include <map>
#include <string.h>

using namespace std;

#define vi vector<int>


char* result_file = "../data/detect_result";
char* diff_dir = "../data/diffresult";
char* diff_result = "faster_result";


void run_diff(char* result_file, char* diff_dir) {
  FILE * fptr = fopen(result_file, "r");
  ssize_t read;
  size_t len = 0;
  char* line = NULL;

  char diff_result_file[256] = "";
  strcat(diff_result_file, diff_dir);
  strcat(diff_result_file, "/");
  strcat(diff_result_file, diff_result);

  printf("diff result file %s\n", diff_result_file);
  FILE* diff_result_ptr = fopen(diff_result_file, "w+");
  while ((read = getline(&line, &len, fptr)) != -1) {
    char filename[256];
    char notused[256];
    // skip blueprint file name
    sscanf(line, "%s%s", notused, filename);

    char diff_file[256] = "";
    strcat(diff_file, diff_dir);
    strcat(diff_file, "/diff");
    int i = 0;
    int x = strlen(diff_file);
    for(i=2;i<strlen(filename);i++) {
      diff_file[i + x - 2] = filename[i];
    }
    diff_file[i + x - 2] = '\0';

    

    fprintf(diff_result_ptr, "%s\n", filename);

    // read second line
    if ((read = getline(&line, &len, fptr)) != -1) {
      fprintf(diff_result_ptr, "%s", line);
    } else {
      break;
    }

    // read 3-rd line for counter
    int max_c = -1;
    int node, c;
    vi detect_nodes;
    while(fscanf(fptr, "%d:%d", &node, &c) == 2) {
      if (c > max_c) {
        max_c = c;
        detect_nodes.clear();
      } else if (c == max_c) {
        detect_nodes.push_back(node);
      }
    }

    // read diff file for actual nodes
    vi actual_nodes;

    printf("diff file: %s\n", diff_file);
    FILE* diff_ptr = fopen(diff_file, "r");
    // if can't find diff file, just continue;
    if (diff_ptr == NULL) {
      fprintf(diff_result_ptr, "0 0 0\n");
      continue;
    }
    while(fscanf(diff_ptr, "%d", &node) == 1) {
      actual_nodes.push_back(node);
    }
    fclose(diff_ptr);
    // sort to use binary search
    sort(actual_nodes.begin(), actual_nodes.end());
    // sort to use binary search
    sort(detect_nodes.begin(), detect_nodes.end());

    int node_match = 0;
    // compare actual_nodes and detect_nodes
    if (detect_nodes.size() > 0) {
      for(i=0;i<actual_nodes.size();i++) {
        // if found such a node
        if (binary_search(detect_nodes.begin(), detect_nodes.end(), actual_nodes[i])) {
          node_match ++;
        }
      }
    }
    fprintf(diff_result_ptr, "%d %d %d\n", node_match, actual_nodes.size(), detect_nodes.size());
  }

  fclose(fptr);
  fclose(diff_result_ptr);
  if (line) {
    free(line);
  }
}

int main() {

  run_diff(result_file, diff_dir);

  return 0;
}


