#include <stdio.h>
#include <vector>
#include <queue>
#include <map>
#include <utility>
#include <cmath>
#include <algorithm>
#include <string>
#include <time.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

using namespace std;

#define vi vector<int> 
#define vvi vector<vector<int> > 
#define vvvi vector<vector<vector<int> > >

char* data_path = "../data/";
double ap_percent = 0.015;
char* output_path = "detect_result";


vvi BFS(vvi edges, int start) {
	int n = edges.size();
	vvi res;
	res.clear();
	// perform BFS
	queue<pair<int, int> > q;
	q.push({start, 0});
	vi visited(n, 0);
	visited[start] = 1;
	while(!q.empty()) {
		pair<int, int> p = q.front();
		q.pop();

		int from = p.first;
		int dist = p.second;
		if (dist >= res.size()) {
			vi temp;
			temp.push_back(from);
			res.push_back(temp);
		} else {
			res[dist].push_back(from);
		}
		for(int i=0;i<edges[from].size();i++) {
			int to = edges[from][i];
			if (!visited[to]) {
				q.push({to, dist + 1});
				visited[to] = 1;
			}
		}
	}

	return res;
}

vvvi SPLD(vvi edges) {
	int n = edges.size();
	// Pre-compute SPLD with BFS
	vvvi splds = vvvi(n);
	for(int i=0;i<n;i++) {
		splds[i] = BFS(edges, i);
	}
	return splds;
}

vvi readGraph(char* filename) {
	int n, m, i, j;
	FILE* fptr = fopen(filename,"r");

	fscanf(fptr, "%d%d%d%d", &n, &m, &i, &j);
	vvi edges = vvi(n);

	int start, end;
	for(i=0;i<m;i++) {
		fscanf(fptr, "%d%d", &start, &end);
		if (find(edges[start].begin(), edges[start].end(), end) == edges[start].end()) {
			edges[start].push_back(end);
		}
		if (find(edges[end].begin(), edges[end].end(), start) == edges[end].end()) {
			edges[end].push_back(start);
		}
	}

	fclose(fptr);
	return edges;
}

bool startsWith(const char *pre, const char *str) {
    size_t lenpre = strlen(pre),
           lenstr = strlen(str);
    return lenstr < lenpre ? false : strncmp(pre, str, lenpre) == 0;
}

vvi readGraphCt(char* filename) {
	int n = 0, m = 0, k = 0;
	if (startsWith("ct100", filename)) {
		k = 100;
	} else if (startsWith("ct10", filename)) {
		k = 10;
	} else if (startsWith("ct20", filename)) {
		k = 20;
	} else if (startsWith("ct30", filename)) {
		k = 30;
	} else if (startsWith("ct40", filename)) {
		k = 40;
	} else if (startsWith("ct50", filename)) {
		k = 50;
	} else if (startsWith("ct60", filename)) {
		k = 60;
	} else if (startsWith("ct70", filename)) {
		k = 70;
	} else if (startsWith("ct80", filename)) {
		k = 80;
	} else if (startsWith("ct90", filename)) {
		k = 90;
	} else if (startsWith("ct4", filename)) {
		k = 4;
	}
	n = 5 * k * k / 4;
	m = k * k * k / 2;

	char filepath[256];
	strcpy(filepath, data_path);
	strcat(filepath, filename);
	FILE* fptr = fopen(filepath, "r");

	vvi edges = vvi(n);

	int start, end;
	for(int i=0;i<m;i++) {
		fscanf(fptr, "%d%d", &start, &end);
		start--;
		end--;
		if (find(edges[start].begin(), edges[start].end(), end) == edges[start].end()) {
			edges[start].push_back(end);
		}
		if (find(edges[end].begin(), edges[end].end(), start) == edges[end].end()) {
			edges[end].push_back(start);
		}
	}

	fclose(fptr);
	return edges;
}


double calc_dist(vvi a, vvi b) {
	int m = max(a.size(), b.size());
	int n = min(a.size(), b.size());

	double sum = 0;
	for(int i=0;i<n;i++) {
		sum += (a[i].size() - b[i].size()) * (a[i].size() - b[i].size());
	}

	vvi c;
	if (a.size() > b.size()) {
		c = a;
	} else {
		c = b;
	}
	for(int i=n;i<m;i++) {
		sum += c[i].size() * c[i].size();
	}
	return sqrt(sum);
}

// check u -> v is connected
int connected(int u, int v, vvi edges) {
	for(int i=0;i<edges[u].size();i++) {
		if (edges[u][i] == v) {
			return 1;
		}
	}
	return 0;
}

void sub_graph_file(int v, int hop, vvi edges, vvi spld, char* filename) {
	vector<int> s;
	for(int i=0;i<=hop && i < spld.size();i++) {
		vi nodes = spld[i];

		// save nodes into s
		for(int j=0;j<nodes.size();j++) {
			s.push_back(nodes[j]);
		}
	}
	
	// check connected between every pair in s.
	vvi sub_edges = vvi(s.size());
	sort(s.begin(), s.end());
	// re-index
	map<int, int> m;
	for(int i=0;i<s.size();i++) {
		m[s[i]] = i;
	}
	int edge_count = 0;
	for(int i=0;i<s.size();i++) {
		for(int j=0;j<edges[s[i]].size();j++) {
			int vv = edges[s[i]][j];
			// if found vv in s, put it into sub graph
			if (binary_search(s.begin(), s.end(), vv)) {
				// found vv in s, save into sub graph

				vi nodes = sub_edges[ m[s[i]] ];

				bool found_node = false;
				for(int k=0;k<nodes.size();k++) {
					if (m[vv] == nodes[k]) {
						found_node = true;
						break;
					}
				}
				if (!found_node) {
					sub_edges[ m[s[i]] ].push_back(m[vv]);
					sub_edges[ m[vv] ].push_back(m[s[i]]);
					edge_count++;
				}
			}
		}

	}
	// save sub_edges into text file
	FILE * fptr = fopen(filename, "w+");

	// fprintf(fptr, "%d %d 1\n", s.size(), edge_count);
	for(int i=0;i<s.size();i++) {
		for(int j=0;j<sub_edges[i].size();j++) {
			int from = i;
			int to = sub_edges[i][j];
			if (from < to) {
				fprintf(fptr, "%d %d\n", from, to);
			}
		}
	}
	fprintf(fptr, "\n");

	fclose(fptr);
}

int basic_check(int hop, vvi b_spld, vvi p_spld) {
	// make sure for every x, x < hop, that the count of spld are the same.
	printf("running basic check\n");
	for(int i=0;i <= hop && i < b_spld.size() && i < p_spld.size();i++) {
		if (b_spld[i].size() != p_spld[i].size()) {
			return 0;
		}
	}
	return 1;
}

char* get_filename(char* filename) {
	// remove ".txt" from filename and return
	int x = strlen(filename);
	char* res = new char[x - 3];
	for(int i=0;i<x - 4;i++) {
		res[i] = filename[i];
	}
	res[x-4] = 0;
	return res;
}

int do_check_file(int hop, int v, vvi b_edges, vvi b_spld, int v2, vvi p_edges, vvi p_spld, char* blueprint, char* physical) {
	char sub_path[256] = "sub_";
	strcat(sub_path, get_filename(blueprint));
	strcat(sub_path, "_");
	strcat(sub_path, get_filename(physical));

	// make directory
	struct stat st = {0};
	if (stat(sub_path, &st) == -1) {
    mkdir(sub_path, 0700);
	}

	char sub_graph_b[256] = "";
	strcat(sub_graph_b, sub_path);
	strcat(sub_graph_b, "/sub_graph_b");

	char sub_graph_p[256] = "";
	strcat(sub_graph_p, sub_path);
	strcat(sub_graph_p, "/sub_graph_p");

	sub_graph_file(v, hop, b_edges, b_spld, sub_graph_b);
	sub_graph_file(v2, hop, p_edges, p_spld, sub_graph_p);
	// using O2 mapping to check it.
	// run command 

	char sub_graph_result[256] = "";
	strcat(sub_graph_result, sub_path);
	strcat(sub_graph_result, "/result");

	char command[1024] = "./check.py ";
	strcat(command, sub_graph_b);
	strcat(command, " ");
	strcat(command, sub_graph_p);
	strcat(command, " ");
	strcat(command, sub_graph_result);
	system(command);

	FILE* fptr = fopen(sub_graph_result, "r");

	int flag;
	fscanf(fptr, "%d", &flag);

	fclose(fptr);
	return flag;
}

void mark_counter(int hop, vvi p_spld, vi & counter) {
	// mark every node in hop and hop + 1
	if (p_spld.size() > hop + 1) {
		for(int i = 0;i<p_spld[hop + 1].size();i++) {
			counter[p_spld[hop + 1][i]]++;
		}
	}
	if (p_spld.size() > hop) {
		for(int i = 0;i<p_spld[hop].size();i++) {
			counter[p_spld[hop][i]]++;
		}
	}
}


void run(char* blueprint, char* physical) {

	//vvi b_edges = readGraph(blueprint);
	//vvi p_edges = readGraph(physical);

	vvi b_edges = readGraphCt(blueprint);
	vvi p_edges = readGraphCt(physical);

	clock_t tStart = clock();
	vvvi b_spld = SPLD(b_edges);
	vvvi p_spld = SPLD(p_edges);

	double spld_time = (double)(clock() - tStart)/CLOCKS_PER_SEC;

	// printf("SPLD cpu time (s) = %.6f\n", (double)(clock() - tStart)/CLOCKS_PER_SEC);

	int n = b_spld.size();

	// pre-compute v and v' mapping
	// use shuffle to select first 1.5% nodes
	vi t;
	for(int i=0;i<n;i++) {
		t.push_back(i);
	}

	srand(time(0));
	random_shuffle(t.begin(), t.end());

	vi selected_ap(t.begin(), t.begin() + (int)(ap_percent * n));

	map<int, int> mapping;

	for(int j=0;j<selected_ap.size();j++) {
		double min_dist = 1e9;
		for(int i=0;i<b_spld.size();i++) {
			double dist = calc_dist(b_spld[i], p_spld[ selected_ap[j] ]);
			if (dist < min_dist) {
				min_dist = dist;
				mapping[selected_ap[j]] = i;
			}
		}
	}
	//printf("Mapping done\n");

	// for each pair v / v'
	tStart = clock();
	vi counter(n, 0);
	for(int i=0;i<selected_ap.size();i++) {
		// use binary to search for x.
		int p_index = selected_ap[i];
		int b_index = mapping[p_index];

		printf("checking mapping %d -> %d\n", p_index, b_index);
		if (b_spld[b_index].size() <= 1 || p_spld[p_index].size() <= 1) {
			counter[p_index] ++;
		} else {
			int possible_hop = 0;
			// make sure spld are exactly the same for every hop.
			for(int i=0;i<n;i++) {
				if (b_spld[b_index][i].size() != p_spld[p_index][i].size()) {
					possible_hop = i;
					break;
				}
				if (b_spld[b_index][i].size() == 0 || p_spld[p_index][i].size() == 0) {
					possible_hop = i;
					break;
				}
			}
			printf("max hop %d <-> %d : %d\n", p_index, b_index, possible_hop);
			int min_hop = 0, max_hop = possible_hop;
			while(max_hop > min_hop) {
				int x = (max_hop + min_hop) / 2;
				// make sure the count of nodes are the same. If not, directly return.
				int flag;
				/*
				if (!basic_check(x, b_spld[b_index], p_spld[p_index])) {
					flag = 0;
				} else {
					flag = do_check(x, b_index, b_edges, b_spld[b_index], p_index, p_edges, p_spld[p_index]);
				}
				*/
				flag = do_check_file(x, b_index, b_edges, b_spld[b_index], p_index, p_edges, p_spld[p_index], blueprint, physical);
				if (flag) {
					min_hop = x + 1;
				} else {
					max_hop = x;
				}
			}
			// check(max_hop) is always false. x == max_hop - 1
			// mark every node with hop = x and hop = x+1 into counter.
			printf("%d hop %d\n", p_index, max_hop - 1);
			if (max_hop != possible_hop) {
				mark_counter(max_hop - 1, p_spld[p_index], counter);
			}
		}
	}
	
	// only get max counter nodes
	vector<pair<int, int> > calc_counter;
	for(int i=0;i<n;i++) {
		calc_counter.push_back({counter[i], i});
	}
	sort(calc_counter.begin(), calc_counter.end());
	reverse(calc_counter.begin(), calc_counter.end());
	// printf("Malfunction-Detection cpu time (s) = %.6f\n", (double)(clock() - tStart)/CLOCKS_PER_SEC);
	double malfunction_time = (double)(clock() - tStart)/CLOCKS_PER_SEC;

	// print results to file
	char o_path[256];

	strcpy(o_path, data_path);
	strcat(o_path, output_path);

	FILE* fptr = fopen(o_path, "a");

	fprintf(fptr, "%s %s :\n", blueprint, physical);
	fprintf(fptr, "SPLD time: %lf, ", spld_time);
	fprintf(fptr, "Malfunction-Detection time: %lf\n", malfunction_time);

	for(int i=0;i<n;i++) {
		if (calc_counter[i].first > 0) {
			fprintf(fptr, "%d:%d  ", calc_counter[i].second, calc_counter[i].first);	
		}
	}
	fprintf(fptr, "\n");
	fclose(fptr);
	printf("%s %s Done\n", blueprint, physical);
}

int main(int argc, char **argv) {

	if (argc != 3) {
		printf("Please use ./haha input output to run this program\n");
		return 0;
	}

	char* filenameb=*(argv+1);
	char* filenamep=*(argv+2);

	run(filenameb, filenamep);

	/*
	char* sub_graph_b = "sub_graph_b";
	char* sub_graph_p = "sub_graph_p";

	int x = check(sub_graph_b, sub_graph_p);

	printf("%d\n", x);
	*/

	return 0;
}
