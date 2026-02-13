
import React, { useState, useEffect, useCallback } from 'react';
import { supabase } from './services/supabaseService';
import type { Job, TabId, Contractor, UserRole } from './types';
import Sidebar from './components/Sidebar';
import Header from './components/Header';
import Dashboard from './components/Dashboard';
import BookingForm from './components/BookingForm';
import AiInspector from './components/AiInspector';
import JobHistory from './components/JobHistory';
import ContractorsPortal from './components/ContractorsPortal';
import Auth from './components/Auth';
import ContractorDashboard from './components/ContractorDashboard';
import AdminPanel from './components/AdminPanel';
import type { Session } from '@supabase/supabase-js';

const App: React.FC = () => {
  const [session, setSession] = useState<Session | null>(null);
  const [userRole, setUserRole] = useState<UserRole | null>(null);
  const [loading, setLoading] = useState(true);

  // --- App State ---
  const [activeTab, setActiveTab] = useState<TabId>('dashboard');
  const [isSidebarOpen, setSidebarOpen] = useState(true);
  const [jobs, setJobs] = useState<Job[]>([]);
  const [contractors, setContractors] = useState<Contractor[]>([]);
  
  useEffect(() => {
    const getSession = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      setSession(session);
    };
    getSession();

    const { data: authListener } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
    });

    return () => {
      authListener.subscription.unsubscribe();
    };
  }, []);

  const fetchUserRole = useCallback(async () => {
    if (session?.user) {
        const { data, error } = await supabase
            .from('profiles')
            .select('role')
            .eq('id', session.user.id)
            .single();

        if (error) {
            console.error('Error fetching user role:', error);
            setUserRole(null);
        } else if (data) {
            setUserRole(data.role as UserRole);
        }
    } else {
        setUserRole(null);
    }
  }, [session]);

  useEffect(() => {
    fetchUserRole();
  }, [session, fetchUserRole]);


  const fetchJobs = useCallback(async () => {
    const { data, error } = await supabase
      .from('jobs')
      .select('*, contractors(name)')
      .order('service_date', { ascending: false });
      
    if (error) {
      console.error('Error fetching jobs:', error);
      setJobs([]);
    } else if (data) {
      const processedJobs = data.map(job => {
        const newJob = { ...job };
        if (Array.isArray(newJob.contractors)) {
            // Handle case where contractors is an array (should not happen with this query)
            newJob.contractor_name = newJob.contractors[0]?.name || null;
        } else if (newJob.contractors) {
            newJob.contractor_name = (newJob.contractors as { name: string }).name;
        }
        delete newJob.contractors;
        return newJob;
      });
      setJobs(processedJobs as Job[]);
    }
  }, []);
  
  const fetchContractors = useCallback(async () => {
    const { data, error } = await supabase
      .from('contractors')
      .select('*')
      .order('name', { ascending: true });

    if (error) {
        console.error('Error fetching contractors:', error);
        setContractors([]);
    } else if (data) {
        setContractors(data as Contractor[]);
    }
  }, []);

  const loadData = useCallback(async () => {
      setLoading(true);
      await Promise.all([fetchJobs(), fetchContractors()]);
      setLoading(false);
  }, [fetchJobs, fetchContractors]);

  useEffect(() => {
    if (session && userRole) { // Only load data if logged in and role is determined
        loadData();
    } else {
        setLoading(false); // Not logged in, no data to load
    }
  }, [session, userRole, loadData]);

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    setSession(null);
    setUserRole(null);
    setJobs([]);
    setContractors([]);
  };

  const handleNewBooking = (newJob: Job) => {
    setJobs(prevJobs => [newJob, ...prevJobs]);
    setActiveTab('history');
  };

  const handleAssignJob = async (jobId: number, contractorId: number) => {
    const contractor = contractors.find(c => c.id === contractorId);
    if (!contractor) return;

    setJobs(prevJobs => prevJobs.map(job => job.id === jobId ? { ...job, contractor_id: contractorId, contractor_name: contractor.name, status: 'In Progress' } : job ));
    
    const { error } = await supabase.from('jobs').update({ contractor_id: contractorId, status: 'In Progress' }).eq('id', jobId);
    if (error) {
        console.error("Failed to assign job:", error);
        fetchJobs(); 
    }
  };

  const handleUpdateJobStatus = async (jobId: number, status: 'Pending' | 'In Progress' | 'Completed') => {
    setJobs(prevJobs => prevJobs.map(job => job.id === jobId ? { ...job, status } : job));
    const { error } = await supabase.from('jobs').update({ status }).eq('id', jobId);
    if (error) {
        console.error("Failed to update job status:", error);
        fetchJobs();
    }
  };

  if (!session) {
    return <Auth />;
  }
  
  const renderAdminAndPMContent = () => {
    if (loading) return <div className="flex items-center justify-center h-full"><p className="text-slate-500">Loading data...</p></div>;
    switch (activeTab) {
      case 'dashboard': return <Dashboard jobs={jobs} contractors={contractors} />;
      case 'booking': return <BookingForm onSuccess={handleNewBooking} />;
      case 'ai': return <AiInspector />;
      case 'history': return <JobHistory jobs={jobs} contractors={contractors} onAssignJob={handleAssignJob} />;
      case 'contractors': return <ContractorsPortal jobs={jobs} contractors={contractors} />;
      case 'admin-panel': return <AdminPanel />;
      default: return <Dashboard jobs={jobs} contractors={contractors} />;
    }
  };

  const renderContractorContent = () => {
    if (loading) return <div className="flex items-center justify-center h-full"><p className="text-slate-500">Loading your jobs...</p></div>;
    return <ContractorDashboard jobs={jobs} onUpdateStatus={handleUpdateJobStatus} />;
  }

  return (
    <div className="flex h-screen bg-slate-50 overflow-hidden font-sans">
      <Sidebar 
        activeTab={activeTab} 
        setActiveTab={setActiveTab} 
        isSidebarOpen={isSidebarOpen} 
        setSidebarOpen={setSidebarOpen}
        role={userRole}
      />
      <main className="flex-1 overflow-y-auto flex flex-col relative">
        <Header 
            activeTab={activeTab} 
            userEmail={session.user.email} 
            onSignOut={handleSignOut}
            role={userRole}
        />
        <div className="p-4 sm:p-6 md:p-8 max-w-7xl mx-auto w-full">
          {(userRole === 'pm' || userRole === 'admin') && renderAdminAndPMContent()}
          {userRole === 'contractor' && renderContractorContent()}
          {!userRole && <div className="flex items-center justify-center h-full"><p className="text-slate-500">Verifying user role...</p></div>}
        </div>
      </main>
    </div>
  );
};

export default App;
