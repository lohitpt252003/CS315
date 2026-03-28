// Assignment 1: External Quicksort
// Simualting the external quick sort algorithm with disk I/O trackning

#include <bits/stdc++.h>

using namespace std;


#define ll long long
#define all(x) x.begin(), x.end()


// This class simulates reading and writing to a disk
// each read/write cost 1 seek and 1 transfer
class DiskSim {
public:
    int b_size; // b
    int k_size; // k
    int max_keys_per_block;

    // the actual disk storage
    unordered_map<int, vector<int>> disk_blocks;
    int next_id;

    // counters for the whole program
    ll seeks_total;
    ll transfers_total;
    
    // counters for just one phase to print later
    ll current_seeks;
    ll current_transfers;

    DiskSim(int b, int k) {
        b_size = b;
        k_size = k;
        max_keys_per_block = b / k;
        next_id = 0;
        seeks_total = 0; transfers_total = 0;
        current_seeks = 0; current_transfers = 0;
    }

    void reset_counters() {
        current_seeks = 0;
        current_transfers = 0;
    }

    vector<int> read(int id) {
        seeks_total++;
        transfers_total++;
        current_seeks++;
        current_transfers++;
        
        if (disk_blocks.find(id) != disk_blocks.end()) return disk_blocks[id];

        return {};
    }

    void write(int id, vector<int> data) {
        seeks_total++;
        transfers_total++;
        current_seeks++;
        current_transfers++;
        disk_blocks[id] = data;
    }

    int get_new_block() {
        int id = next_id++;
        disk_blocks[id] = {};
        return id;
    }

    void delete_blocks(vector<int> ids) {
        for (int i = 0; i < ids.size(); i++) disk_blocks.erase(ids[i]);
    }

    // helper to write a list of keys to disk and return the block ids
    vector<int> save_keys(vector<int> keys) {
        vector<int> ids;
        for (int i = 0; i < keys.size(); i += max_keys_per_block) {
            int end_idx = min((int)keys.size(), i + max_keys_per_block);
            vector<int> chunk(keys.begin() + i, keys.begin() + end_idx);
            int new_id = get_new_block();
            write(new_id, chunk);
            ids.push_back(new_id);
        }

        return ids;
    }
    
    // helper to read everything back from a list of blocks
    vector<int> load_keys(vector<int> ids) {
        vector<int> res;
        for (int i = 0; i < ids.size(); i++) {
            vector<int> temp = read(ids[i]);
            res.insert(res.end(), all(temp));
        }

        return res;
    }
};

// Represents a file on the disk
struct FileData {
    vector<int> blocks;
    int total_keys;
    DiskSim* disk;

    FileData() {
        total_keys = 0;
        disk = NULL;
    }

    FileData(vector<int> b, int n, DiskSim* d) {
        blocks = b;
        total_keys = n;
        disk = d;
    }
    
    vector<int> get_all() {
        vector<int> k = disk -> load_keys(blocks);
        if (k.size() > total_keys) k.resize(total_keys);
        return k;
    }

    void cleanup() {
        disk -> delete_blocks(blocks);
        blocks.clear();
        total_keys = 0;
    }
};

// structs to hold info for printing at the end
struct PassInfo {
    int num;
    int depth;
    int pivot_val;
    int keys_in;
    int less_k, eq_k, gr_k;
    int less_b, eq_b, gr_b;
    ll seeks;
    ll transfers;
};

struct PhaseCost {
    string n;
    ll s;
    ll t;
};


class Quicksort {
public:
    DiskSim* disk;
    int mem; // m blocks available in ram

    int pass_count;
    vector<PassInfo> logs;
    vector<PhaseCost> costs;

    Quicksort(DiskSim* d, int m) {
        disk = d;
        mem = m;
        pass_count = 0;
    }

    FileData run_sort(FileData f, int depth = 0) {
        // base case if there is nothing to sort
        if (f.total_keys <= 1) return f;

        // if it fits in memory, just sort it normally
        if (f.blocks.size() <= mem) {
            disk -> reset_counters();
            vector<int> k = f.get_all();
            f.cleanup();
            
            sort(all(k)); // standard c++ sort

            vector<int> new_b = disk -> save_keys(k);
            FileData ret(new_b, k.size(), disk);
            
            string name = "In-memory sort (depth=" + to_string(depth) + ", keys=" + to_string(f.total_keys) + ")";
            costs.push_back({name, disk -> current_seeks, disk -> current_transfers});
            return ret;
        }

        // otherwise we have to do external partition pass
        pass_count++;
        int my_pass = pass_count;
        disk -> reset_counters();

        // pick pivot using median of mostly 3 blocks
        int pivot = 0;
        vector<int> cands;
        
        vector<int> b1 = disk -> read(f.blocks[0]);
        if (b1.size() > 0) cands.push_back(b1[0]);
        else cands.push_back(0);
        
        if (f.blocks.size() >= 2) {
            int mid = f.blocks.size() / 2;
            vector<int> b2 = disk -> read(f.blocks[mid]);
            if (b2.size() > 0) cands.push_back(b2[0]);
        }
        
        if (f.blocks.size() >= 3) {
            vector<int> b3 = disk -> read(f.blocks.back());
            if (b3.size() > 0) cands.push_back(b3[0]);
        }
        
        sort(all(cands));
        pivot = cands[cands.size() / 2];

        // partition step
        vector<int> less_k, eq_k, gr_k;
        for (int i = 0; i < f.blocks.size(); i++) {
            vector<int> cur = disk -> read(f.blocks[i]);
            for (int j = 0; j < cur.size(); j++) {
                if (cur[j] < pivot) less_k.push_back(cur[j]);
                else if (cur[j] == pivot) eq_k.push_back(cur[j]);
                else gr_k.push_back(cur[j]);
            }
        }

        f.cleanup(); // free old blocks

        // save the three parts to disk
        FileData less_f(disk -> save_keys(less_k), less_k.size(), disk);
        FileData eq_f(disk -> save_keys(eq_k), eq_k.size(), disk);
        FileData gr_f(disk -> save_keys(gr_k), gr_k.size(), disk);

        ll p_seeks = disk -> current_seeks;
        ll p_transfers = disk -> current_transfers;

        // save logs for output
        PassInfo p;
        p.num = my_pass; p.depth = depth; p.pivot_val = pivot;
        p.keys_in = less_k.size() + eq_k.size() + gr_k.size();
        p.less_k = less_k.size(); p.eq_k = eq_k.size(); p.gr_k = gr_k.size();
        p.less_b = less_f.blocks.size(); p.eq_b = eq_f.blocks.size(); p.gr_b = gr_f.blocks.size();
        p.seeks = p_seeks; p.transfers = p_transfers;
        logs.push_back(p);

        string pname = "Partition pass #" + to_string(my_pass) + " (depth=" + to_string(depth) + ", pivot=" + to_string(pivot) + ")";
        costs.push_back({pname, p_seeks, p_transfers});

        // recurse
        FileData left_sorted = run_sort(less_f, depth + 1);
        FileData right_sorted = run_sort(gr_f, depth + 1);

        // merge them all back together
        vector<int> final_res;
        if (left_sorted.total_keys > 0) {
            vector<int> l = left_sorted.get_all();
            final_res.insert(final_res.end(), all(l));
            left_sorted.cleanup();
        }
        
        final_res.insert(final_res.end(), all(eq_k));
        
        if (right_sorted.total_keys > 0) {
            vector<int> r = right_sorted.get_all();
            final_res.insert(final_res.end(), all(r));
            right_sorted.cleanup();
        }
        eq_f.cleanup();

        return FileData(disk -> save_keys(final_res), final_res.size(), disk);
    }
};

void print_sep() {
    cout << "======================================================================" << endl;
}

int main(int argc, char* argv[]) {
    if (argc != 6) {
        cout << "Wrong number of arguments!" << endl;
        cout << "Usage: ./external_quicksort <input-file> <n> <k> <b> <m>" << endl;
        return 1;
    }

    string file_name = argv[1];
    int n = atoi(argv[2]);
    int k = atoi(argv[3]);
    int b = atoi(argv[4]);
    int m = atoi(argv[5]);

    int kpb = b / k; // keys per block
    int total_b = ceil((double)n / kpb);

    print_sep();
    cout << "External Quicksort Simulation" << endl;
    print_sep();
    cout << "File: " << file_name << endl;
    cout << "N: " << n << endl;
    cout << "Keysize: " << k << endl;
    cout << "Blocksize: " << b << endl;
    cout << "Mem: " << m << " blocks" << endl;
    
    ifstream fin(file_name);
    if (!fin.is_open()) {
        cout << "Error opening file " << file_name << endl;
        return 1;
    }

    vector<int> my_keys;
    int temp;
    while (fin >> temp) my_keys.push_back(temp);

    fin.close();

    if (my_keys.size() > n) my_keys.resize(n);

    DiskSim disk(b, k);
    disk.reset_counters();

    FileData start_file(disk.save_keys(my_keys), my_keys.size(), &disk);

    ll load_s = disk.current_seeks;
    ll load_t = disk.current_transfers;

    cout << endl << "[Phase 0] Initial disk load" << endl;
    cout << "Blocks written: " << start_file.blocks.size() << endl;
    cout << "Seeks: " << load_s << endl;
    cout << "Transfers: " << load_t << endl;
    cout << endl;

    Quicksort qs(&disk, m);
    FileData end_file = qs.run_sort(start_file);

    disk.reset_counters();
    vector<int> sorted_ans = end_file.get_all();
    ll read_s = disk.current_seeks;
    ll read_t = disk.current_transfers;

    // check if it is right
    vector<int> c_ans = my_keys;
    sort(c_ans.begin(), c_ans.end());
    bool isok = (sorted_ans == c_ans);

    print_sep();
    cout << "FINAL RESULTS" << endl;
    print_sep();

    cout << endl << "1. Total partition passes: " << qs.pass_count << endl;

    cout << endl << "2. Detail of each pass:" << endl;
    cout << "---------------------------------" << endl;
    for (int i = 0; i < qs.logs.size(); i++) {
        PassInfo& p = qs.logs[i];
        cout << " Pass #" << p.num << " (depth " << p.depth << ")" << endl;
        cout << "   Pivot: " << p.pivot_val << endl;
        cout << "   Total keys: " << p.keys_in << endl;
        cout << "   < pivot: " << p.less_k << " (" << p.less_b << " blocks)" << endl;
        cout << "   = pivot: " << p.eq_k << " (" << p.eq_b << " blocks)" << endl;
        cout << "   > pivot: " << p.gr_k << " (" << p.gr_b << " blocks)" << endl;
        cout << "   Seeks: " << p.seeks << ", Transfers: " << p.transfers << endl << endl;
    }

    cout << "3. Phase costs:" << endl;
    cout << "---------------------------------" << endl;
    cout << left << setw(40) << "Name" << right << setw(10) << "Seeks" << setw(10) << "Transfers" << endl;
    cout << left << setw(40) << "Loading data" << right << setw(10) << load_s << setw(10) << load_t << endl;
    for (int i = 0; i < qs.costs.size(); i++) cout << left << setw(40) << qs.costs[i].n << right << setw(10) << qs.costs[i].s << setw(10) << qs.costs[i].t << endl;
    cout << left << setw(40) << "Reading result" << right << setw(10) << read_s << setw(10) << read_t << endl;
    cout << endl;

    cout << "4. Total I/O costs:" << endl;
    cout << "---------------------------------" << endl;
    cout << "  Total Seeks:     " << disk.seeks_total << endl;
    cout << "  Total Transfers: " << disk.transfers_total << endl;
    cout << "  Combined Total:  " << disk.seeks_total + disk.transfers_total << endl;
    cout << endl;

    print_sep();
    if (isok) cout << "VERDICT: OK (its sorted correctly)" << endl;
    else cout << "VERDICT: WRONG (not sorted right)" << endl;

    return 0;
}
