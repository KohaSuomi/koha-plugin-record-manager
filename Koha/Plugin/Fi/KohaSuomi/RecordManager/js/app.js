
const app = Vue.createApp({
    data() {
        return {
            contents: [],
            error: null,
            selectedContent: null,
            loading: true,
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
                    console.error('Error fetching contents:', error);
                    this.error = 'An error occurred while fetching the contents';
                }).finally(() => {
                    this.loading = false;
                });
        }, 
        fetchPossibleHosts(id) {
            axios.get(`/api/v1/contrib/kohasuomi/records/orphans/${id}/possible-hosts`)
                .then(response => {
                    this.possible_hosts = response.data.possible_hosts;
                })
                .catch(error => {
                    console.error('Error fetching possible hosts:', error);
                    this.error = 'An error occurred while fetching possible hosts';
                });
        }
    },
    mounted() {
        this.fetchContents();
    },
});

app.mount('#recordManagerApp');