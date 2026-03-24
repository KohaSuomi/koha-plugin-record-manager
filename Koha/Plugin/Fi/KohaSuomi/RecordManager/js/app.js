const app = Vue.createApp({

    data() {
        return {
            contents: [],
            error: null,
            selectedContent: null,
            loading: true,
            loading_modal: false,
            possible_hosts: [],
            componentpart: null,
            sortKey: '',
            sortOrder: 1,
            searchQuery: '',
            record_id: null
        };
    },

    computed: {
        // Suodatettu ja järjestetty lista
        sortedContents() {
            let filtered = this.contents;

            if (this.searchQuery) {
                const q = this.searchQuery.toLowerCase();
                filtered = this.contents.filter(content =>
                    (content.author && content.author.toLowerCase().includes(q)) ||
                    (content.title && content.title.toLowerCase().includes(q)) ||
                    (content.control_number && content.control_number.toLowerCase().includes(q)) ||
                    (content.host_item && content.host_item.toLowerCase().includes(q))
                );
            }

            if (!this.sortKey) return filtered;

            return [...filtered].sort((a, b) => {
                let valA = a[this.sortKey] || '';
                let valB = b[this.sortKey] || '';
                if (valA < valB) return -1 * this.sortOrder;
                if (valA > valB) return 1 * this.sortOrder;
                return 0;
            });
        },

        // Sorttausikoni sarakeotsikoille
        sortOrderIcon() {
            return this.sortOrder === 1 ? 'bi bi-caret-up-fill' : 'bi bi-caret-down-fill';
        }
    },

    methods: {


        exportList() {
            if (!this.sortedContents || this.sortedContents.length === 0) {
                alert("Ei vietävää dataa");
                return;
            }

            const headers = ["Tietue", "Kontrollikenttä", "Emo"];

            const rows = this.sortedContents.map(item => [
                `${item.author || ""}, ${item.title || ""}`,
                item.control_number || "",
                item.host_item || ""
            ]);

            const csv = "\uFEFF" + [headers, ...rows]
                .map(r => r.map(v => `"${v}"`).join(";"))
                .join("\n");

            const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
            const url = URL.createObjectURL(blob);

            // 🚀 Luo aikaleima muodossa YYYYMMDD_HHMMSS
            const now = new Date();
            const pad = (n) => n.toString().padStart(2, "0");
            const timestamp = `${now.getFullYear()}${pad(now.getMonth()+1)}${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;

            const filename = `tietueet_${timestamp}.csv`;

            const link = document.createElement("a");
            link.href = url;
            link.setAttribute("download", filename);

            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            URL.revokeObjectURL(url);
        },
        // Palauttaa järjestyksen oletukseksi
        resetSort () {
        
            this.sortKey = '';
            this.sortOrder = 1;
        },

        // Sarakkeiden sorttaus
        sortBy(key) {
            if (this.sortKey === key) this.sortOrder *= -1;
            else { this.sortKey = key; this.sortOrder = 1; }
        },

        // Palauttaa luokan prosentille (haalea tausta ja musta teksti)
        scoreClass(score) {
            if (score >= 50) return 'score-badge score-high';
            return 'score-badge score-medium';
        },

        // Hae tietueet
        fetchContents() {
            axios.get(`/api/v1/contrib/kohasuomi/records/orphans`)
                .then(response => { this.contents = response.data.orphans; })
                .catch(error => { console.error('virhe haettaessa emoja:', error); this.error = 'Virhe tietoja haettaessa'; })
                .finally(() => { this.loading = false; });
        },

        // Hae mahdolliset emot
        fetchPossibleHosts(id) {
            this.record_id = id;
            this.loading_modal = true;

            axios.get(`/api/v1/contrib/kohasuomi/records/orphans/${id}/possible-hosts`)
                .then(response => { 
                    this.possible_hosts = response.data.possible_hosts; 
                    this.componentpart = response.data.component_data; 
                })
                .catch(error => { 
                    console.error('Error fetching possible hosts:', error); 
                    this.error = 'An error occurred while fetching possible hosts'; 
                })
                .finally(() => { 
                    this.loading_modal = false; 
                });
        },

        // Poista tietue
        deleteRecord() {
            if (!confirm('Haluatko varmasti poistaa tämän tietueen? Tätä toimintoa ei voi peruuttaa.')) return;

            axios.delete(`/api/v1/biblios/${this.record_id}`)
                .then(() => {
                    this.contents = this.contents.filter(content => content.id !== this.record_id);
                    this.possible_hosts = [];
                    this.record_id = null;
                })
                .catch(error => { 
                    console.error('Error deleting record:', error); 
                    this.error = 'An error occurred while deleting the record'; 
                })
                .finally(() => {  
                    const modalEl = document.getElementById('possibleHostsModal');
                    const modalInstance = bootstrap.Modal.getInstance(modalEl);

                    if (modalInstance) {
                        modalInstance.hide();
                    }
                });
        },

            // LISÄTTY: Yhdistä osakohde emokohteeseen
            combineToHost(host_biblionumber) {
                if (!confirm('Haluatko varmasti yhdistää tämän osakohteen valittuun emokohteeseen?')) return;

                axios.post(`/api/v1/contrib/kohasuomi/records/orphans/combine`, {
                    orphan_biblionumber: this.record_id,
                    host_biblionumber: host_biblionumber
                })
                .then(() => {
                    // Poistetaan yhdistetty osakohde listalta
                    this.contents = this.contents.filter(content => content.id !== this.record_id);
                    this.possible_hosts = [];
                    this.record_id = null;
                })
                .catch(error => {
                    console.error('Error combining orphan to host:', error);
                    this.error = 'Virhe yhdistettäessä osakohdetta emoon';
                })
                .finally(() => {
                    const modalEl = document.getElementById('possibleHostsModal');
                    const modalInstance = bootstrap.Modal.getInstance(modalEl);
                    if (modalInstance) modalInstance.hide();
                });
        }   

   },

    // Kun komponentti mountataan, haetaan tietueet
    mounted() {
        this.fetchContents();
    }

});

app.mount('#recordManagerApp');