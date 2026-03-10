
const app = Vue.createApp({
    data() {
        return {
            contents: [],
            error: null,
            selectedContent: null,
            loading: true,
            loading_modal: false,
            possible_hosts: []
        };
    },

    methods: {
        fetchContents() {
            axios.get(`/api/v1/contrib/kohasuomi/records/orphans`)
                .then(response => {
                    this.contents = response.data.orphans;
                })
                .catch(error => {
                    console.error('virhe haettaessa emoja:', error);
                    this.error = 'Virhe tietoja haettaessa';
                }).finally(() => {
                    this.loading = false;
                });
        }, 
        fetchPossibleHosts(id) {
            this.loading_modal = true;
            axios.get(`/api/v1/contrib/kohasuomi/records/orphans/${id}/possible-hosts`)
                .then(response => {
                    this.possible_hosts = response.data.possible_hosts;
                })
                .catch(error => {
                    console.error('Error fetching possible hosts:', error);
                    this.error = 'An error occurred while fetching possible hosts';
                }).finally(() => {
                    this.loading_modal = false;
                });
        }
    },
    mounted() {
        this.fetchContents();
    },
});

app.mount('#recordManagerApp');